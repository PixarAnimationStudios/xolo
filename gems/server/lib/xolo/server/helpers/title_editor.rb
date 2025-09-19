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
