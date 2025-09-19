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

        # The default minimum OS for versions
        # # @return [String] the default minimum OS for versions
        #############
        def default_min_os
          if Xolo::Server.config.default_min_os.pix_empty?
            Xolo::Core::BaseClasses::Version::DEFAULT_MIN_OS.to_s
          else
            Xolo::Server.config.default_min_os.to_s
          end
        end

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

        # Instantiate a Server::Version, with access to the Sinata App instance
        #
        # If given a Hash, use it with .new to instantiate fresh
        #
        # If given a title and version, the title may be a String, the title's
        # title, or a Xolo::Server::Title object. If it's a Xolo::Server::Title
        # that object will be used as the title_object for the version object.
        #
        # In all cases, set the server_app_instance in the new version onject
        # to use for access from the version object to the Sinatra App instance
        # for the session and api connection objects
        #
        # @param data [Hash] hash to use with .new
        # @param title [String, Xolo::Server::Title] title to use with .load
        # @param version [String] version to use with .load
        #
        # @return [Xolo::Server::Version]
        #################
        def instantiate_version(data = nil, title: nil, version: nil)
          title_obj = nil

          if data
            title = data[:title]
          elsif title.is_a?(Xolo::Server::Title)
            title_obj = title
            title = title_obj.title
          end

          vers =
            if data.is_a? Hash
              Xolo::Server::Version.new data

            elsif title && version
              halt_on_missing_title title
              halt_on_missing_version title, version

              Xolo::Server::Version.load title, version
            else
              msg = 'Invalid data to instantiate a Xolo::Server::Version'
              log_error msg
              halt 400, { status: 400, error: msg }
            end

          vers.title_object = title_obj || instantiate_title(title)
          vers.server_app_instance = self
          vers
        end

        # Halt 404 if a version doesn't exist
        # @pararm [String] The title of a Title
        # @return [void]
        ##################
        def halt_on_missing_version(title, version)
          return if all_versions(title).include? version

          msg = "No version '#{version}' for title '#{title}'."
          log_debug "ERROR: #{msg}"
          resp_body = @streaming_now ? msg : { status: 404, error: msg }

          # don't halt if we're streaming, just error out
          raise Xolo::NoSuchItemError, msg if @streaming_now

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
          resp_body = @streaming_now ? msg : { status: 409, error: msg }

          # don't halt if we're streaming, just error out
          raise Xolo::NoSuchItemError, msg if @streaming_now

          halt 409, resp_body
        end

        # Halt 409 if a version is locked
        # @pararm [String] The title of a Title
        # @return [void]
        ##################
        def halt_on_locked_version(title, version)
          return unless Xolo::Server::Version.locked? title, version

          msg = "Version '#{version}' of title '#{title}' is being modified by another admin. Try again later."
          log_debug "ERROR: #{msg}"
          halt 409, { status: 409, error: msg }
        end

      end # TitleEditor

    end # Helpers

  end # Server

end # module Xolo
