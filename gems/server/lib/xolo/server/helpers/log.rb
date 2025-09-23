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

    module Helpers

      # This is mixed in to Xolo::Server::App (as a helper, available in route processing)
      # and in Xolo::Server::Title and Xolo::Server::Version,
      # for simplified access to the main server logger, with access to session IDs
      #
      # The Title and Version objects must be instantiated with the current session object
      # in order for this to work.
      #
      # See Xolo::Server::Helpers::Titles#instantiate_title for how this happens
      #
      # All those things need have have #session set before calling the log_* methods
      module Log

        # Module Methods
        #######################
        #######################

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # Instance Methods
        #######################
        ######################

        ###############################
        def logger
          Xolo::Server.logger
        end

        ###############################
        def session_svr_obj_id
          return @session_svr_obj_id if @session_svr_obj_id

          @session_svr_obj_id =
            ("#{session[:xolo_id]}-#{object_id}" if session[:xolo_id])
        end

        ###############################
        def log_debug(msg, alert: false)
          logger.debug(session_svr_obj_id) { msg }
          send_alert msg, :DEBUG if alert
        end

        ###############################
        def log_info(msg, alert: false)
          logger.info(session_svr_obj_id) { msg }
          send_alert msg, :INFO if alert
        end

        ###############################
        def log_warn(msg, alert: false)
          logger.warn(session_svr_obj_id) { msg }
          send_alert msg, :WARNING if alert
        end

        ###############################
        def log_error(msg, alert: false)
          logger.error(session_svr_obj_id) { msg }
          send_alert msg, :ERROR if alert
        end

        ###############################
        def log_fatal(msg, alert: false)
          logger.fatal(session_svr_obj_id) { msg }
          send_alert msg, :FATAL if alert
        end

        ###############################
        def log_unknown(msg, alert: false)
          logger.unknown(session_svr_obj_id) { msg }
          send_alert msg, :UNKNOWN if alert
        end

      end # Log

    end # Helpers

  end # Server

end # module Xolo
