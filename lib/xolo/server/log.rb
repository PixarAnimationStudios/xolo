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
      LOG_FILE = LOG_DIR + 'xoloserver.log'

      # TODO: log rotation
      DFT_LOG_DAYS_TO_KEEP = 14

      # Easier for reporting level changes - the index is the severity number
      LEVELS = %w[DEBUG INFO WARN ERROR FATAL UNKNOWN]

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
