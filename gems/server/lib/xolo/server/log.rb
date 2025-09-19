# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#
#

# frozen_string_literal: true

# main module
module Xolo

  module Server

    # constants and methods for writing to the log
    module Log

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      DATETIME_FORMAT = '%F %T'

      # Easier for reporting level changes - the index is the severity number
      LEVELS = %w[DEBUG INFO WARN ERROR FATAL UNKNOWN].freeze

      # THe log format - we use 'progname' to hole the
      # session object, if there is one.
      #
      LOG_FORMATTER = proc do |severity, datetime, progname, msg|
        progname &&= " #{progname}"
        "#{datetime.strftime DATETIME_FORMAT} #{severity}#{progname}: #{msg}\n"
      end

      LOG_DIR = Xolo::Server::DATA_DIR + 'logs'
      LOG_FILE_NAME = 'xoloserver.log'
      LOG_FILE = LOG_DIR + LOG_FILE_NAME

      # log rotation, compression, pruning

      # keep this many days of logs total
      DFT_LOG_DAYS_TO_KEEP = 30

      # compress the log files when they are this many days old
      DFT_LOG_COMPRESS_AFTER_DAYS = 7

      # shell out to bzip2 - no need for another gem requirement.
      BZIP2 = '/usr/bin/bzip2'

      # compressed files have this extension
      BZIPPED_EXTNAME = '.bz2'

      # This file is touched after each log rotation run.
      # Its mtime is used to decide if we should to it again
      LAST_ROTATION_FILE = LOG_DIR + 'last_log_rotation'

      # When we rotate the main log to .0 we repoint the logger to this
      # temp filename, then rename the main log to .0, then rename this
      # temp file to the main log. This way the logger never has to be
      # reinitialized.
      TEMP_LOG_FILE = LOG_DIR + 'temp_xoloserver.log'

      # top-level logger for the server as a whole
      #############################################
      def self.logger
        return @logger if @logger

        LOG_DIR.mkpath
        LOG_FILE.pix_touch

        @logger = Logger.new(
          LOG_FILE,
          datetime_format: DATETIME_FORMAT,
          formatter: LOG_FORMATTER
        )

        @logger
      end

      # A mutex for the log rotation process
      #
      # TODO: use Concrrent Ruby instead of Mutex
      #
      # @return [Mutex] the mutex
      #####################
      def self.rotation_mutex
        @rotation_mutex ||= Mutex.new
      end

      # change log level of the server logger, new requests should inherit it
      #############################################
      # def self.set_level(level, user: :unknown)
      #   lvl_const = level.to_s.upcase.to_sym
      #   if Logger.constants.include? lvl_const
      #     lvl = Logger.const_get lvl_const
      #     logger.debug "changing log level to #{lvl_const} (#{lvl}) by #{user}"
      #     logger.level = lvl
      #     logger.info "log level changed to #{lvl_const} by #{user}"

      #     { loglevel: lvl_const }
      #   else
      #     { error: "Unknown level '#{level}', use one of: debug, info, warn, error, fatal, unknown" }
      #   end
      # end

      # Log rotation is done by a Concurrent::TimerTask, which checks every
      # 5 minutes to see if it should do anything.
      # It will only do a rotation if the current time is in the midnight hour
      # (00:00 - 00:59) AND if the last rotation was more than 23 hours ago.
      #
      # @return [Concurrent::TimerTask] the timed task to do log rotation
      def self.log_rotation_timer_task
        return @log_rotation_timer_task if @log_rotation_timer_task

        @log_rotation_timer_task =
          Concurrent::TimerTask.new(execution_interval: 300) { rotate_logs }

        logger.info 'Created Concurrent::TimerTask for nightly log rotation.'
        @log_rotation_timer_task
      end

      # rotate the log file, keeping some number of old ones and possibly
      # compressing them after some time.
      # The log rotation built into ruby's Logger class doesn't allow this kind of
      # behavior, And I don't want to require yet another 3rd party gem.
      #
      # @param force [Boolean] force rotation even if not midnight
      #
      # @return [void]
      ###############################
      def self.rotate_logs(force: false)
        return unless rotate_logs_now?(force: force)

        # TODO: Use Concurrent ruby rather than this instance variable
        mutex = Xolo::Server::Log.rotation_mutex

        if mutex.locked?
          log_warn 'Log rotation already running, skipping this run'
          return
        end

        mutex.lock

        logger.info 'Starting Log Rotation'

        # how many to keep?
        days_to_keep = Xolo::Server.config.log_days_to_keep || Xolo::Server::Log::DFT_LOG_DAYS_TO_KEEP

        # when to compress?
        compress_after = Xolo::Server.config.log_compress_after_days || Xolo::Server::Log::DFT_LOG_COMPRESS_AFTER_DAYS

        # no compression if compress_after is less than zero or greater/equal to days to keeps
        compress_after = nil if compress_after.negative? || compress_after >= days_to_keep

        # work down thru the number to keep
        days_to_keep.downto(1) do |age|
          # the previous file to the newly aged file
          # if we're moving to a newly aged .3, this is .2
          prev_age = age - 1

          # rename a previous file to n+1, e.g. file.2 becomes file.3
          # This will overwrite an existing new_file, which is how we
          # delete the oldest
          prev_file = LOG_DIR + "#{LOG_FILE_NAME}.#{prev_age}"
          new_file = LOG_DIR + "#{LOG_FILE_NAME}.#{age}"
          if prev_file.file?
            logger.info "Moving log file #{prev_file.basename} => #{new_file.basename}"
            prev_file.rename new_file
          end

          # Do the same for any already compressed files
          prev_compressed_file = LOG_DIR + "#{LOG_FILE_NAME}.#{prev_age}#{BZIPPED_EXTNAME}"
          new_compressed_file = LOG_DIR + "#{LOG_FILE_NAME}.#{age}#{BZIPPED_EXTNAME}"
          if prev_compressed_file.file?
            logger.info "Moving log file #{prev_compressed_file.basename} => #{new_compressed_file.basename}"
            prev_compressed_file.rename new_compressed_file
          end

          next unless compress_after

          # compress the one we just moved if we should
          compress_log(new_file) if age >= compress_after && new_file.file?
        end # downto

        # now for the current logfile...
        rotate_live_log compress_after&.zero?

        # touch the last rotation file
        LAST_ROTATION_FILE.pix_touch
      rescue StandardError => e
        logger.error "Error rotating logs: #{e}"
        e.backtrace.each { |l| logger.error "..#{l}" }
      ensure
        Xolo::Server::Log.rotation_mutex.unlock if Xolo::Server::Log.rotation_mutex.owned?
      end

      # Rotate the current log file without losing any log entries
      #
      # @return [void]
      ###############################
      def self.rotate_live_log(compress_zero)
        # first, delete any old tmp file
        TEMP_LOG_FILE.delete if TEMP_LOG_FILE.file?

        # then repoint the logger to the temp file
        logger.reopen TEMP_LOG_FILE

        # make sure it has data in it
        logger.info 'Starting New Log'

        # then rename the main log to .0
        zero_file = LOG_DIR + "#{LOG_FILE_NAME}.0"
        logger.info "Moving log file #{LOG_FILE_NAME} => #{zero_file.basename}"

        LOG_FILE.rename zero_file

        # then rename the temp file to the main log.
        # The logger will still log to it because it holds a
        # filehandle to it, and doesn't care about its name.
        TEMP_LOG_FILE.rename LOG_FILE

        # compress the zero file if we should
        compress_log(zero_file) if compress_zero
      end

      # should we rotate the logs right now?
      #
      # @return [Boolean] true if we should rotate the logs
      ###############################
      def self.rotate_logs_now?(force: false)
        return true if force

        now = Time.now
        # only during the midnight hour
        return false unless now.hour.zero?

        # only if the last rotation was more than 23 hrs ago
        # if no rotation_file, assume 24 hrs ago.
        rotation_file = Xolo::Server::Log::LAST_ROTATION_FILE
        last_rotation = rotation_file.file? ? rotation_file.mtime : (now - (24 * 3600))

        twenty_three_hrs_ago = now - (23 * 3600)

        # less than (<) means its been more than 23 hrs
        # since the last rotation was before 23 hrs ago.
        last_rotation < twenty_three_hrs_ago
      end

      #########################
      def self.compress_log(file)
        zipout = `/usr/bin/bzip2  #{file.to_s.shellescape}`

        if $CHILD_STATUS.success?
          logger.info "Compressed log file: #{file}"
        else
          logger.error "Failed to compress log file: #{file}"
          zipout.lines.each { |l| logger.error ".. #{l.chomp}" }
        end # if success?
      end

    end # module Log

    # Wrapper for Xolo::Server::Log.logger,
    # also available as Xolo::Server.logger from anywhere.
    # Within Sinatra routes and views, its available via the #logger instance method.
    #########################################
    def self.logger
      Log.logger
    end

    # set the log level of the server logger
    #########################################
    def self.set_log_level(level, admin:)
      # make sure the level is valid
      raise ArgumentError, "Unknown log level '#{level}'" unless Log::LEVELS.include? level.to_s.upcase

      # unknonwn always gets logged
      logger.unknown "Setting log level to #{level} by #{admin}"

      logger.level = level
    end

  end #  Server

end # module Xolo
