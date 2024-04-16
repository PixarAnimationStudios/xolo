# Copyright 2023 Pixar
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

      # constants and methods for accessing the Jamf Pro server
      module JamfPro

        ### Module methods
        ###
        ### These are available as module methods but not as 'helper'
        ### methods in sinatra routes & views.
        ###
        ##############################
        ##############################

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # Our main connection to Jamf Pro
        # TODO: allow using APIClients
        # @return [void]
        def self.connect_to_jamf
          Jamf.cnx.connect(
            host: Xolo::Server.config.jamf_hostname,
            port: Xolo::Server.config.jamf_port,
            verify_cert: Xolo::Server.config.jamf_verify_cert,
            ssl_version: Xolo::Server.config.jamf_ssl_version,
            open_timeout: Xolo::Server.config.jamf_open_timeout,
            timeout: Xolo::Server.config.jamf_timeout,
            user: Xolo::Server.config.jamf_api_user,
            pw: Xolo::Server.config.jamf_api_pw
          )
          Xolo::Server.logger.info "Connected to Jamf Pro at #{Jamf.cnx.base_url} as user '#{Xolo::Server.config.jamf_api_user}'"
        end

        ### Instance methods
        ###
        ### These are available directly in sinatra routes and views
        ###
        ##############################
        ##############################

      end # JamfPro

    end # Helpers

  end # Server

end # module Xolo
