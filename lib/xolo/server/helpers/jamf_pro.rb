# Copyright 2025 Pixar
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
      # from the Xolo server
      #
      # This is used both as a 'helper' in the Sinatra server,
      # and an included mixin for the Xolo::Server::Title and
      # Xolo::Server::Version classes.
      #
      # This means methods here are available in instances of
      # those classes, and in all routes, views, and helpers in
      # Sinatra.
      #
      module JamfPro

        # Constants
        #
        ##############################
        ##############################

        PATCH_REPORT_UNKNOWN_VERSION = 'UNKNOWN_VERSION'
        PATCH_REPORT_JPAPI_PAGE_SIZE = 500

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

        # A connection to Jamf Pro via ruby-jss.
        #
        # We don't use the default connection but
        # use this method to create standalone ones as needed
        # and ensure they are disconnected, (or will timeout)
        # when we are done.
        #
        # TODO: allow using APIClients
        #
        # @return [Jamf::Connection] A connection object
        ##########################
        def jamf_cnx(refresh: false)
          if refresh
            @jamf_cnx = nil
            log_debug 'Jamf: Refreshing Jamf connection'
          end

          return @jamf_cnx if @jamf_cnx

          @jamf_cnx = Jamf::Connection.new(
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
          log_debug "Jamf: Connected to Jamf Pro at #{@jamf_cnx.base_url} as user '#{Xolo::Server.config.jamf_api_user}'. KeepAlive: #{@jamf_cnx.keep_alive?}, Expires: #{@jamf_cnx.token.expires}. cnx ID: #{@jamf_cnx.object_id}"

          @jamf_cnx
        end

        # The id of
        #
        def jamf_xolo_category_id
          @jamf_xolo_category_id ||= Jamf::Category.valid_id(Xolo::Server::JAMF_XOLO_CATEGORY, cnx: jamf_cnx).to_s
        end

        # if there's a forced_exclusion group defined in the server config
        # return it's name, but only if it exists in jamf. If it doesn't
        # return nil and alert someone
        #
        # @return [String] The valid name of the forced exclusion group
        #####################
        def valid_forced_exclusion_group_name
          return @valid_forced_exclusion_group_name if defined?(@valid_forced_exclusion_group_name)

          the_grp_name = Xolo::Server.config.forced_exclusion

          if the_grp_name
            if Jamf::ComputerGroup.all_names(cnx: jamf_cnx).include? the_grp_name
              @valid_forced_exclusion_group_name = the_grp_name
            else
              msg = "ERROR: The forced_exclusion group '#{Xolo::Server.config.forced_exclusion}' in xolo server config does not exist in Jamf"
              log_error msg, alert: true
              @valid_forced_exclusion_group_name = nil
            end

          # not in config
          else
            @valid_forced_exclusion_group_name = nil
          end
        end

      end # JamfPro

    end # Helpers

  end # Server

end # module Xolo
