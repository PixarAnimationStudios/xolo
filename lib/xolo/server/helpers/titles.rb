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

      # constants and methods for working with Xolo Titles on the server
      module Titles

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

        # A list of all known titles
        # @return [Array<String>]
        ############
        def all_titles
          Xolo::Server::Title.all_titles
        end

        # A an array of all server titles as Title objects
        # @return [Array<Xolo::Server::Title>]
        ############
        def all_title_objects
          all_titles.map { |t| instantiate_title t }
        end

        # Instantiate a Server::Title
        # If given a string, use it with .load to read the title from disk
        #
        # If given a Hash, use it with .new to instantiate fresh
        #
        # In all cases, set the session, to use for logging
        # (the reason this method exists)
        #
        # @param data [Hash, String] hash to use with .new or name to use with .load
        #
        # @return [Xolo::Server::Title]
        #################
        def instantiate_title(data)
          title =
            case data
            when Hash
              Xolo::Server::Title.new data

            when String
              halt_on_missing_title data
              Xolo::Server::Title.load data

            else
              halt 400, 'Invalid data to instantiate a Xolo.Server::Title'
            end

          title.server_app_instance = self
          title
        end

        # Halt 404 if a title doesn't exist
        # @pararm [String] The title of a Title
        # @return [void]
        ##################
        def halt_on_missing_title(title)
          return if all_titles.include? title

          msg = "Title '#{title}' does not exist."
          log_debug "ERROR: #{msg}"
          halt 404, { error: msg }
        end

        # Halt 409 if a title already exists
        # @pararm [String] The title of a Title
        # @return [void]
        ##################
        def halt_on_existing_title(title)
          return unless all_titles.include? title

          msg = "Title '#{title}' already exists."
          log_debug "ERROR: #{msg}"
          halt 409, { error: msg }
        end

        # Halt 409 if a title is locked
        # @pararm [String] The title of a Title
        # @return [void]
        ##################
        def halt_on_locked_title(title)
          return unless Xolo::Server::Title.locked? title

          msg = "Title '#{title}' is being modified by another admin. Try again later."
          log_debug "ERROR: #{msg}"
          halt 409, { error: msg }
        end

      end # TitleEditor

    end # Helpers

  end # Server

end # module Xolo
