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

      # constants and methods for accessing the Title Editor server
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
      # This is used as a 'helper' in the Xolo server, so that routes and views have
      # access to the instance methods, and also included in the Xolo::Server::Title
      # class to that instances also have access to those methods.
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
        def title_editor_cnx
          wcnx = Windoo::Connection.new(
            name: "title-editor-cnx-#{Time.now.strftime('%F-%T')}",
            host: Xolo::Server.config.title_editor_hostname,
            user: Xolo::Server.config.title_editor_api_user,
            pw: Xolo::Server.config.title_editor_api_pw,
            open_timeout: Xolo::Server.config.title_editor_open_timeout,
            timeout: Xolo::Server.config.title_editor_timeout,
            keep_alive: false
          )

          log_debug "Title Editor: Connected to TitleEditor at #{wcnx.base_url} as user '#{Xolo::Server.config.title_editor_api_user}'. KeepAlive: #{wcnx.keep_alive?}, Expires: #{wcnx.token.expires}"

          wcnx
        end

      end # TitleEditor

    end # Helpers

  end # Server

end # module Xolo
