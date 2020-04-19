### Copyright 2017 Pixar

###
###    Licensed under the Apache License, Version 2.0 (the "Apache License")
###    with the following modification; you may not use this file except in
###    compliance with the Apache License and the following modification to it:
###    Section 6. Trademarks. is deleted and replaced with:
###
###    6. Trademarks. This License does not grant permission to use the trade
###       names, trademarks, service marks, or product names of the Licensor
###       and its affiliates, except as required to comply with Section 4(c) of
###       the License and to reproduce the content of the NOTICE file.
###
###    You may obtain a copy of the Apache License at
###
###        http://www.apache.org/licenses/LICENSE-2.0
###
###    Unless required by applicable law or agreed to in writing, software
###    distributed under the Apache License with the above modification is
###    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
###    KIND, either express or implied. See the Apache License for the specific
###    language governing permissions and limitations under the Apache License.
###
###

# the main module
module D3

  # the server app
  module Server

    # This module defines our custom Logger instance from the config settings
    # and makes it available in the .logger module method,
    # which is used anywhere outside of a route
    # (inside of a route, the #logger method is locally available)
    #
    module Log

      # Using an instance of this as the Logger target sends logfile writes
      # to all registered streams as well as the file
      class LogFileWithStream < File

        def write(str)
          super # writes out to the file
          flush
          # # send to any active streams
          # D3::Server::Log.log_streams.keys.each do |active_stream|
          #   # ignore streams closed at the client end,
          #   # they get removed when a new stream starts
          #   # see the route: get '/subscribe_to_log_stream'
          #   next if active_stream.closed?
          #
          #   # send new data to the stream
          #   active_stream << "#{D3::Server::Log::LOGSTREAM_DATA_PFX}#{str}\n\n"
          # end
        end # write

      end # class LogFileWithStream

      # mapping of integer levels to symbols
      LOG_LEVELS = {
        unknown: Logger::UNKNOWN,
        fatal: Logger::FATAL,
        error: Logger::ERROR,
        warn: Logger::WARN,
        info: Logger::INFO,
        debug: Logger::DEBUG
      }.freeze

      DATE_TIME_FORMAT = '%Y-%m-%d %H:%M:%S'.freeze

      # log Streaming

      # ServerSent Events data lines always start with this
      LOGSTREAM_DATA_PFX = 'data:'.freeze

      # Send this to the clients at least every LOGSTREAM_KEEPALIVE_MAX secs
      # even if there's no data for the stream
      LOGSTREAM_KEEPALIVE_MSG = "#{LOGSTREAM_DATA_PFX} I'm Here!\n\n".freeze
      LOGSTREAM_KEEPALIVE_MAX = 10

      # the clients will recognize D3_LOG_STREAM_CLOSED and stop trying
      # to connect via ssh.
      LOGSTREAM_CLOSED_PFX = "#{LOGSTREAM_DATA_PFX} D3_LOG_STREAM_CLOSED:".freeze

      # Start up the logger
      # make the first log entry for this run,
      # and return it so it can be used by the server
      # when it does `set :logger, Log.startup(@log_level)`
      def self.startup(level = D3::Server.config.log_level)
        @logger = make_logger

        # date and line format
        @logger.datetime_format = DATE_TIME_FORMAT

        @logger.formatter = proc do |severity, datetime, _progname, msg|
          "#{datetime}: [#{severity}] #{msg}\n"
        end

        # level
        level &&= LOG_LEVELS[level.to_sym]
        level ||= LOG_LEVELS[D3::Server.config.log_level]
        @logger.level = level

        # first startup entry
        @logger.unknown "D3 Server v#{D3::VERSION} starting up. PID: #{$PROCESS_ID}, Port: #{D3::Server.config.port}"

        # if debug, log our config
        if @logger.level == Logger::DEBUG
          @logger.debug 'Config: '
          D3::Server::Config::CONF_KEYS.keys.each do |key|
            @logger.debug "  D3::Server.config.#{key} = #{D3::Server.config.send key}"
          end
        end

        # return the logger, the server uses it as a helper
        @logger
      end # startup

      def self.make_logger
        # the log file itself
        logfile = LogFileWithStream.new(D3::Server.config.log_file, 'a')
        logs_kept = D3::Server.config.logs_to_keep

        # return the logger created using a LogFileWithStream instance
        return Logger.new logfile unless logs_kept && logs_kept > 0

        log_size = D3::Server.config.log_max_megs * 1024 * 1024
        Logger.new logfile, logs_kept, log_size
      end # make_logger

      # general access to the logger as D3::Server::Log.logger.
      # From inside server routes and filters, its just #logger
      def self.logger
        @logger ||= startup
      end

      # a Hash  of registered log streams
      # streams are keys, valus are their IP addrs
      # see the `get '/subscribe_to_log_stream'` route
      #
      # def self.log_streams
      #   @log_streams ||= {}
      # end
      #
      # def self.clean_log_streams
      #   log_streams.delete_if do |stream, ip|
      #     if stream.closed?
      #       logger.debug "Removing closed log stream for #{ip}"
      #       true
      #     else
      #       false
      #     end # if
      #   end # delete if
      # end # clean_log_streams

    end # module log

  end # module server

  # access from everywhere as D3.logger
  def self.logger
    Server::Log.logger
  end

  # log an exception via D3.log_exception - multiple log lines,
  # the first being the error message the rest being indented backtrace
  def self.log_exception(exception)
    logger.error exception.to_s
    exception.backtrace.each { |l| logger.error "..#{l}" }
  end

end # D3
