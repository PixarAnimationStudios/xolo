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

      # constants and methods for accessing the Jamf Pro server
      module JamfPro

        # Constants
        #
        ##############################
        ##############################

        #
        # Each version gets one policy for initial installation.
        #
        # when piloted, the targets will be any tar

        # install live:fd
        #  => xolo install title
        #
        # runs 'jamf policy -trigger xolo-install-current-<title>'
        # the xolo server maintains the trigger
        #################
        #
        # install pilot:
        #  => xolo install title version
        #
        # runs 'jamf policy -trigger xolo-install-<title>-<version>'
        # the xolo server maintains the trigger
        ##################
        #
        # auto-install on pilot groups or target groups
        #  => xolo sync
        #
        # runs 'jamf policy'
        # the xolo server maintains the scopes for the policies
        # patch policies will be run as needed
        ##################
        #
        # get the lates JSON data about titles and versions
        # => xolo update
        #
        # runs 'jamf policy -trigger xolo-update'
        # the xolo server maintains a package that deploys the JSON file
        ##################
        #
        # list available titles or versions
        #  => xolo list-titles
        #
        # reads from a local JSON file of title & version data
        # maintained by the xolo server and pushed out via
        # a checkin policy
        ##################

        # Module methods
        #
        # These are available as module methods but not as 'helper'
        # methods in sinatra routes & views.
        #
        ##############################
        ##############################

        # when this module is included
        ##############################
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # when this module is extended
        def self.extended(extender)
          Xolo.verbose_extend extender, self
        end

        # Instance methods
        #
        # These are available directly in sinatra routes and views
        #
        ##############################
        ##############################

        # A connection to Jamd Pro via ruby-jss
        # We don't use the default connection but
        # use this method to create standalone ones as needed
        # and ensure they are disconnected, (or will timeout)
        # when we are done.
        # TODO: allow using APIClients
        #
        # @return [Jamf::Connection] A connection object
        def jamf_cnx
          jcnx = Jamf::Connection.new(
            name: "jamf-pro-cnx-#{Time.now.strftime('%F-%T')}",
            host: Xolo::Server.config.jamf_hostname,
            port: Xolo::Server.config.jamf_port,
            verify_cert: Xolo::Server.config.jamf_verify_cert,
            ssl_version: Xolo::Server.config.jamf_ssl_version,
            open_timeout: Xolo::Server.config.jamf_open_timeout,
            timeout: Xolo::Server.config.jamf_timeout,
            user: Xolo::Server.config.jamf_api_user,
            pw: Xolo::Server.config.jamf_api_pw,
            keep_alive: false
          )
          log_debug "Jamf: Connected to Jamf Pro at #{jcnx.base_url} as user '#{Xolo::Server.config.jamf_api_user}'. KeepAlive: #{jcnx.keep_alive?}, Expires: #{jcnx.token.expires}"

          jcnx
        end

      end # JamfPro

    end # Helpers

  end # Server

end # module Xolo
