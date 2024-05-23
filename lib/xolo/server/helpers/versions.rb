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

      # constants and methods for working with Xolo Versions on the server
      # As a helper, these are available in the App instance context, for all
      # routes and views
      module Versions

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

        # A list of all known versions of a title
        # @return [Array<String>]
        ############
        def all_versions(title)
          Xolo::Server::Version.all_versions(title)
        end

        # A list of all known versions of a title
        # @return [Array<Xolo::Server::Version>]
        ############
        def all_version_instances(title)
          all_versions(title).map { |v| instantiate_version title: title, version: v }
        end

        # Instantiate a Server::Version
        #
        # If given a Hash, use it with .new to instantiate fresh
        #
        # If given a two-item array of [title, version], use .load
        # load the title, and then the title's #version_object method
        # to read the version from disk
        #
        # In all cases, set the server_app_instance, to use for
        # access from the version object to the Sinatra App instance
        # for the session and api connection objects
        #
        # @param data [Hash, Array] hash to use with .new
        # @param title [String] title to use with .load
        # @param version [String] version to use with .load
        #
        # @return [Xolo::Server::Version]
        #################
        def instantiate_version(data = nil, title: nil, version: nil)
          vers =
            if data.is_a? Hash
              Xolo::Server::Version.new data
            elsif title && version
              halt_on_missing_title title
              halt_on_missing_version title, version

              Xolo::Server::Version.load title, version
            else
              halt 400, 'Invalid data to instantiate a Xolo.Server::Version'
            end

          vers.server_app_instance = self
          vers
        end

        # Halt 404 if a title doesn't exist
        # @pararm [String] The title of a Title
        # @return [void]
        ##################
        def halt_on_missing_version(title, version)
          return if all_versions(title).include? version

          msg = "No version '#{version}' for title '#{title}'."
          log_debug "ERROR: #{msg}"
          resp_body = @streaming ? msg : { error: msg }

          halt 404, resp_body
        end

        # Halt 409 if a title already exists
        # @pararm [String] The title of a Title
        # @return [void]
        ##################
        def halt_on_existing_version(title, version)
          return unless all_versions(title).include? version

          msg = "Version '#{version}' of title '#{title}' already exists."
          log_debug "ERROR: #{msg}"
          resp_body = @streaming ? msg : { error: msg }
          halt 409, resp_body
        end

      end # TitleEditor

    end # Helpers

  end # Server

end # module Xolo
