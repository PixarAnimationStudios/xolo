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

        # Instantiate a Server::Title with access to the Sinatra app instance,
        #
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
              msg = 'Invalid data to instantiate a Xolo::Server::Title'
              log_error msg

              halt 400, { status: 400, error: msg }
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
          halt 404, { status: 404, error: msg }
        end

        # Halt 409 if a title already exists
        # @pararm [String] The title of a Title
        # @return [void]
        ##################
        def halt_on_existing_title(title)
          return unless all_titles.include? title

          msg = "Title '#{title}' already exists."
          log_debug "ERROR: #{msg}"
          halt 409, { status: 409, error: msg }
        end

        # Halt 409 if a title is locked
        # @pararm [String] The title of a Title
        # @return [void]
        ##################
        def halt_on_locked_title(title)
          return unless Xolo::Server::Title.locked? title

          msg = "Title '#{title}' is being modified by another admin. Try again later."
          log_debug "ERROR: #{msg}"
          halt 409, { status: 409, error: msg }
        end

        # when freezing or thawing, are we dealing with a list of computers
        # or a list of users, for whom we need to get all their assigned computers
        # @param targets [Array<String>] a list of computers or usernames
        # @param users [Boolean] is the list usernames? if not, its computers
        # @return [Array<String>] a list of computers to freeze or thaw
        ########################
        def expand_freeze_thaw_targets(targets:, users:)
          return targets unless users

          log_debug "Expanding user list to freeze or thaw: #{targets}"

          expanded_targets = []
          all_users = Jamf::User.all_names(cnx: jamf_cnx)
          targets.each do |user|
            next unless all_users.include? user

            expanded_targets += Jamf::User.fetch(name: user, cnx: jamf_cnx).computers.map { |c| c[:name] }
          end

          expanded_targets.uniq
        end

      end # TitleEditor

    end # Helpers

  end # Server

end # module Xolo
