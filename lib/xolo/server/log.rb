# Copyright 2024 Pixar
#
#    Licensed under the Apache License, Version 2.0 (the "Apache License")
#    with the following modification; you may not use this file except in
#    compliance with the Apache License and the following modification to it:
#    Section 6. Trademarks. is deleted and replaced with:
#
#    6. Trademarks. This License does not grant permission to use the trade
#       names, trademarks, service marks, or product names of the Licensor
#       and its affiliates, except as required to comply with Section 4(c) of
#       the License and to reproduce the content of the NOTICE file.
#
#    You may obtain a copy of the Apache License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the Apache License with the above modification is
#    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#    KIND, either express or implied. See the Apache License for the specific
#    language governing permissions and limitations under the Apache License.
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

      # Easier for reporting level changes - the index is the severity number
      LEVELS = %w[DEBUG INFO WARN ERROR FATAL UNKNOWN].freeze

      # This file is touched after each log rotation run.
      # Its mtime is used to decide if we should to it again
      LAST_ROTATION_FILE = LOG_DIR + 'last_log_rotation'

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
          Concurrent::TimerTask.new(execution_interval: 300) do |_task|
            now = Time.now

            # only do anything during the midnight hour
            break unless now.hour.zero?

            # only do anything if the last rotation was more than 23 hrs ago

            last_rotation =
              if Xolo::Server::Log::LAST_ROTATION_FILE.file?
                Xolo::Server::Log::LAST_ROTATION_FILE.mtime
              else
                now - (24 * 3600)
              end
            twenty_three_hrs_ago = now - (23 * 3600)
            break if last_rotation < twenty_three_hrs_ago

            # do it
            rotate_logs
          end

        @log_rotation_timer_task
      end

      # rotate the log file, keeping some number of old ones and possibly
      # compressing them after some time.
      # The log rotation built into ruby's Logger class doesn't allow this kind of
      # behavior, And I don't want to require yet another 3rd party gem.
      #
      # @return [void]
      ###############################
      def self.rotate_logs
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
          prev_file.rename new_file if prev_file.file?

          # Do the same for any already compressed files
          prev_compressed_file = LOG_DIR + "#{LOG_FILE_NAME}.#{prev_age}#{BZIPPED_EXTNAME}"
          new_compressed_file = LOG_DIR + "#{LOG_FILE_NAME}.#{age}#{BZIPPED_EXTNAME}"
          prev_compressed_file.rename new_compressed_file if prev_compressed_file.file?

          next unless compress_after

          # compress the one we just moved if we should
          compress_log(new_file) if age >= compress_after && new_file.file?
        end # downto

        # now for the current logfile...
        current_log = LOG_DIR + LOG_FILE_NAME
        zero_file = LOG_DIR + "#{LOG_FILE_NAME}.0"

        # copy, and then empty the current one. We don't move/rename it
        # because the logger will still have its filehandle open
        # and it'll keep writing into the moved/renamed one.
        # TODO: = make this deal with the possibility of log lines being written between these steps
        current_log.pix_cp zero_file
        current_log.pix_save nil
        compress_log(zero_file) if compress_after&.zero?

        LAST_ROTATION_FILE.pix_touch
        logger.info 'Starting New Log'
      end

      #########################
      def self.compress_log(file)
        zipout = `/usr/bin/bzip2  #{file.to_s.shellescape}`

        if $CHILD_STATUS.success?
          logger.info "Compressed old log file: #{file}"
        else
          logger.error "Failed to compress old log file: #{file}"
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

  end #  Server

end # module Xolo
