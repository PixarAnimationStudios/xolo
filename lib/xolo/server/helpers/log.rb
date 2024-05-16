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

        def logger
          Xolo::Server.logger
        end

        def log_debug(msg)
          logger.debug(session[:xolo_id]) { "#{msg}" }
        end

        def log_info(msg)
          logger.info(session[:xolo_id]) { "#{msg}" }
        end

        def log_warn(msg)
          logger.warn(session[:xolo_id]) { "#{msg}" }
        end

        def log_error(msg)
          logger.error(session[:xolo_id]) { "#{msg}" }
        end

        def log_fatal(msg)
          logger.fatal(session[:xolo_id]) { "#{msg}" }
        end

        def log_unknown(msg)
          logger.unknown(session[:xolo_id]) { "#{msg}" }
        end

      end # Log

    end # Helpers

  end # Server

end # module Xolo
