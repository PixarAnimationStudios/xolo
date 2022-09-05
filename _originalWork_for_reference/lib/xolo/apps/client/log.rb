# Copyright 2018 Pixar
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


#
module Xolo

  # Log a message to the d3 log, possibly sending it to stderr as well.
  #
  # The message will appear in the log:
  #   - if the log is writable by the current user
  #   - based upon its severity level, and the current Xolo::Log.level.
  #     Any message more severe than the log level will be logged.
  #
  # The message will also appear on stderr if the message severity is
  # at or higher than the current @@verbosity.
  #
  # If the @@verbosity is :debug the messages to stderr will be prefixed with
  # the message severity.
  #
  # In the d3 command, @@verbosity is controlled with the -v, -q and -d
  # options
  #
  # See also Xolo::Log.log and the ruby Logger module.
  # See also Xolo::verbosity=
  #
  # @param msg[String] the message to log
  #
  # @param severity[Symbol] the severity level of this message, defaults to
  #   Xolo::Log::DFT_LOG_LEVEL
  #
  # @return [void]
  #
  def self.log (msg, severity = Xolo::Log::DFT_LOG_LEVEL)

    message_severity = Xolo::Log.check_level(severity)

    # send to stderr if needed
    if message_severity >= @@verbosity
      if  @@verbosity ==  Xolo::Log::LOG_LEVELS[:debug]
        STDERR.puts "#{severity}: #{msg}"
      else
        STDERR.puts msg
      end
    end #

    # send to the logger
    Xolo::Log.instance.log msg, severity
  end

  # Log the lines of backtrace from the most recent exception
  # but only if the current severity is :debug
  def self.log_backtrace
    return unless Xolo::LOG.level == :debug
    $@.each{|line| Xolo.log "   #{line}", :debug }
  end



  class Log

    ############### Mixin Modules #################

    include Singleton

    ############### Class Constants #################

    # The default log file
    DFT_LOG_FILE = "/var/log/d3.log"

    # the possible log severity levels
    LOG_LEVELS = {
      :debug => Logger::DEBUG,
      :info => Logger::INFO,
      :warn => Logger::WARN,
      :error => Logger::ERROR,
      :fatal => Logger::FATAL
    }

    # the default log level
    DFT_LOG_LEVEL = LOG_LEVELS[:info]

    # the default verbosity level (logs to stderr)
    DFT_VERBOSITY = LOG_LEVELS[:warn]

    # THe "program name" that appears in the logs.
    # see #progname=
    DFT_LOG_PROGNAME = "d3-module"

    # timestamp format, this is 2015-02-15 13:02:34
    DFT_LOG_TIME_FMT = "%Y-%m-%d %H:%M:%S"



    ############### Class Methods #################

    # Return the numeric value of a log level
    # or raise an exception if the level is invalid.
    #
    # @param level[Symbol, Integer] the level to check, should be one of the
    #   keys of LOG_LEVELS
    #
    # @return [integer] the numeric value of the log level
    #
    def self.check_level(level)
      valid = true
      case level
      when Symbol
        valid = false unless LOG_LEVELS.keys.include? level
        value = LOG_LEVELS[level]
      when Fixnum
        valid = false unless LOG_LEVELS.values.include? level
        value = level
      else
        valid = false
      end #case
      raise JSS::InvalidDataError, "Severity level must be one of :#{LOG_LEVELS.keys.join ', :'} OR #{LOG_LEVELS.values.join ', '}" unless valid
      return value
    end

    ############### Attribtues #################

    # @return [Pathname] the logfile being written
    attr_reader :log_file

    # @return [Symbol] the current severity level of logging
    attr_reader :level

    # @return [String] the strftime format of the timestamps in the log
    attr_reader :timestamp_format

    # @return [String] the program name associated with a log entry
    attr_reader :progname

    ############### Constructor #################

    def initialize

      # Set default values
      @log_file = Pathname.new DFT_LOG_FILE
      @level = DFT_LOG_LEVEL
      @timestamp_format = DFT_LOG_TIME_FMT
      @progname = DFT_LOG_PROGNAME


      # Set values from config if available.
      # @note: progname needs to be set by the prog using the module,
      #   e.g. d3, d3admin, d3helper
      #   not by the config
      @log_file = Pathname.new(Xolo::CONFIG.log_file) if Xolo::CONFIG.log_file
      @level = Xolo::CONFIG.log_level if Xolo::CONFIG.log_level
      @timestamp_format = Xolo::CONFIG.log_timestamp_format if Xolo::CONFIG.log_timestamp_format

      # the logger will be created if the file is writable
      writable =  if @log_file.file?
                    @log_file.writable?
                  else
                    @log_file.parent.writable?
                  end

      if writable
        @logger = Logger.new @log_file
        @logger.level = Xolo::Log.check_level(@level)
        set_format
      else
        @logger = nil
      end

    end # init

    ############### Public Instance Methods #################

    # Send a message to be logged
    # If the severity is less severe than the current level,
    # the message won't be written to the log.
    #
    # @param msg[String] the message to write to the log
    #
    # @param severity[Symbol] the severity of this message.
    #   If below the current log_level the message won't be written.
    #   Must be one of the keys of LOG_LEVELS. Defaults to :info.
    #
    # @param progname[String] the name of the program creating this msg.
    #   Defaults to the currently-set log_progname (see #log_progname=)
    #   or DFT_LOG_PROGNAME.
    #
    # @return [Boolean] the message was handled appropriately, or not
    #
    def log (msg, severity = DFT_LOG_LEVEL)
      return nil unless @logger
      @logger.add(Xolo::Log.check_level(severity), msg, @progname)
    end

    # Set a new severity-level for logging.
    # Messages less severe than this won't be written to the log.
    #
    # @param new_level[Symbol] the new log level, must be one of the keys of Xolo::Log::LOG_LEVELS
    #
    # @return [void]
    #
    def level= (new_level)
      return nil unless @logger
      @level = Xolo::Log.check_level(new_level)
      @logger.level = @level
    end


    # Set a new program-name for log entries
    #
    # @param new_name[String] the new program name for log entries
    #
    # @return [void]
    #
    def progname= (new_name)
      @progname = new_name.to_s
      set_format
    end


    # Set a new timestamp format
    #
    # @param fmt[String] the new format, an strftime string.
    #
    # @return [void]
    #
    def timestamp_format= (new_format)
      return nil unless @logger
      @timestamp_format = new_format.to_s
      @logger.datetime_format = @timestamp_format
    end # timestamp_format=

    private

    # set up the log line format
    def set_format
      return nil unless @logger
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime.strftime @timestamp_format} #{progname} [#{$$}]: #{severity}: #{msg}\n"
      end #
    end # set format

  end # class Log

  # the singleton instance of our logger
  LOG = Xolo::Log.instance
end # module Xolo

