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

      # constants and methods for accessing the Title Editor server
      #
      # This is both uses as a 'helper' in the Sinatra server,
      # and an included mixin for the Xolo::Server::Title and
      # Xolo::Server::Version classes.
      #
      # This means methods here are available in instances of
      # those classes, and in all routes, views, and helpers in
      # Sinatra.
      #
      # NOTE: The names of various attributes of Title Editor SoftwareTitles
      # and Xolo Titles are not always in sync.
      # For example:
      #   - the :display_name of the Xolo Title is the :name of a SoftwareTitle
      #   - the :title of a Xolo Title id the :id of a SoftwareTitle
      #   - the numeric :softwareTitleId of the SoftwareTitle doesn't exist in a Xolo Title
      #
      # See Windoo::SoftwareTitle::JSON_ATTRIBUTES for more details about them.
      # The Xolo server code will deal with all the translations.
      #
      module TitleEditor

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

        # Module Methods
        # These must be called using Xolo::Server::Helpers::TitleEditor.<method>
        ###############################
        ##############################

        # Given a Windoo::Patch object, and an
        # app_name: & app_bundle_id: or an ea_name:
        # Set the component criteria for the patch to
        # be based either on the app data, or ea
        #
        # @param patch [Windoo::Patch] the patch to set
        #
        # @param title [String] the title for this patch
        # @param app_name [String] the name of the app to use in app-based requirements,
        #   must be used with app_bundle_id, cannot be used with ea_name
        #
        # @param app_bundle_id [String] the bundle id of the app to use in app-based requirements
        #   must be used with app_name, cannot be used with ea_name
        #
        # @param ea_name [String] the name of the EA to use in EA-based requirements (the ted_ea_key)
        #   Cannot be used with app_name or app_bundle_id
        #
        # @return [void]
        ################################
        def self.set_patch_component_criteria(ted_patch, app_name: nil, app_bundle_id: nil, ea_name: nil)
          # delete any already there and make a new one
          ted_patch.delete_component
          ted_patch.add_component name: ted_patch.container.id, version: ted_patch.version

          comp = ted_patch.component

          if ea_name
            set_ea_component(comp, ea_name, ted_patch.version)
          else
            set_app_component(comp, app_name, app_bundle_id, ted_patch.version)
          end
        end

        # @return [void]
        ##############################
        def self.set_ea_component(comp, ea_name, version)
          comp.criteria.add_criterion(
            type: 'extensionAttribute',
            name: ea_name,
            operator: 'is',
            value: version
          )
        end

        # @return [void]
        ##############################
        def self.set_app_component(comp, app_name, app_bundle_id, version)
          comp.criteria.add_criterion(
            name: 'Application Title',
            operator: 'is',
            value: app_name
          )

          comp.criteria.add_criterion(
            name: 'Application Bundle ID',
            operator: 'is',
            value: app_bundle_id
          )

          comp.criteria.add_criterion(
            name: 'Application Version',
            operator: 'is',
            value: version
          )
        end

        # Instance methods
        #
        # These are available directly in sinatra routes and views
        #
        ##############################
        ##############################

        # A connection to the Title Editor via Windoo
        # We don't use the Windoo default connection but
        # use this method to create standalone ones as needed
        # and ensure they are disconnected, (or will timeout)
        # when we are done.
        #
        # @return [Windoo::Connection] A connection object
        ##############################
        def ted_cnx
          return @ted_cnx if @ted_cnx

          @ted_cnx = Windoo::Connection.new(
            name: "title-editor-cnx-#{Time.now.strftime('%F-%T')}",
            host: Xolo::Server.config.ted_hostname,
            user: Xolo::Server.config.ted_api_user,
            pw: Xolo::Server.config.ted_api_pw,
            open_timeout: Xolo::Server.config.ted_open_timeout,
            timeout: Xolo::Server.config.ted_timeout,
            keep_alive: false
          )

          log_debug "Title Editor: Connected at #{@ted_cnx.base_url}, user '#{Xolo::Server.config.ted_api_user}'. KeepAlive: #{@ted_cnx.keep_alive?}, Expires: #{@ted_cnx.token.expires}. cnxID: #{@ted_cnx.object_id}"

          @ted_cnx
        end

      end # TitleEditor

    end # Helpers

  end # Server

end # module Xolo
