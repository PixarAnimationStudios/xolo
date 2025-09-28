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

        # @return [String] The start of the Jamf Pro URL for GUI/WebApp access
        ################
        def jamf_gui_url
          return @jamf_gui_url if @jamf_gui_url

          host = Xolo::Server.config.jamf_gui_hostname
          host ||= Xolo::Server.config.jamf_hostname

          port = Xolo::Server.config.jamf_gui_port
          port ||= Xolo::Server.config.jamf_port

          @jamf_gui_url = "https://#{host}:#{port}"
        end

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

        # The id of the 'xolo' category in Jamf Pro.s
        #
        def jamf_xolo_category_id
          @jamf_xolo_category_id ||=
            if Jamf::Category.all_names(cnx: jamf_cnx).include? Xolo::Server::JAMF_XOLO_CATEGORY
              Jamf::Category.valid_id(Xolo::Server::JAMF_XOLO_CATEGORY, cnx: jamf_cnx).to_s
            else
              Jamf::Category.create(name: Xolo::Server::JAMF_XOLO_CATEGORY, cnx: jamf_cnx).save
            end
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
