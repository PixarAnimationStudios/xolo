# Copyright 2023 Pixar
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

    # A title in Xolo, as used on the server
    class Title < Xolo::Core::BaseClasses::Title

      # Mixins
      #############################
      #############################

      include Xolo::Server::Helpers::JamfPro
      include Xolo::Server::Helpers::TitleEditor

      # Constants
      ######################
      ######################

      # On the server, xolo titles are represented by directories
      # in this directory, named with the title name.
      #
      # So a title 'foobar' would have a directory
      #    (Xolo::Server::DATA_DIR)/titles/foobar/
      # and in there will be a file
      #    foobar.json
      # with the data for the Title instance itself
      #
      # Also in there will be a 'versions' dir containing json
      # files for each version of the title.
      # See {Xolo::Server::Version}
      #
      TITLES_DIR = Xolo::Server::DATA_DIR + 'titles'

      # when creating new titles in the title editor,
      # This is the 'currentVersion', which is required
      # when creating.
      # When the first version/patch is added, the
      # title's value for this will be updated.
      NEW_TITLE_CURRENT_VERSION = '0.0.0'

      # Class Methods
      ######################
      ######################

      # @return [Array<Pathname>] A list of all known title dirs
      ######################
      def self.title_dirs
        TITLES_DIR.children
      end

      # @return [Array<String>] A list of all known titles,
      #   just the basenames of all the title_dirs
      ######################
      def self.all_titles
        title_dirs.map(&:basename).map(&:to_s)
      end

      # The title dir for a given title on the server,
      # which may or may not exist.
      #
      # @pararm title [String] the title we care about
      # @return [Pathname]
      #####################
      def self.title_dir(title)
        TITLES_DIR + title
      end

      # The the local JSON file containing the current values
      # for the given title
      #
      # @pararm title [String] the title we care about
      # @return [Pathname]
      #####################
      def self.title_data_file(title)
        title_dir(title) + "#{title}.json"
      end

      # @return [Xolo::Server::Title] load an existing title
      #   from the on-disk JSON file
      ######################
      def self.load(title)
        new parse_json(title_data_file(title).read)
      end

      # @param title [String] the title we are looking for
      # @pararm cnx [Windoo::Connection] The Title Editor connection to use
      # @return [Boolean] Does the given title exist in the Title Editor?
      ###############################
      def self.in_title_editor?(title, cnx: nil)
        ensure_disconnect = false
        unless cnx
          cnx = title_editor_cnx
          ensure_disconnect = true
        end

        Windoo::SoftwareTitle.all_ids(cnx: cnx).include? title
      ensure
        cnx&.disconnect if ensure_disconnect
      end

      # Attributes
      ######################
      ######################

      # Constructor
      ######################
      ######################

      # Instance Methods
      ######################
      ######################

      # The title dir for this title on the server
      # @return [Pathname]
      #########################
      def title_dir
        self.class.title_dir title
      end

      # The title data file for this title on the server
      # @return [Pathname]
      #########################
      def title_data_file
        self.class.title_data_file title
      end

      # Save a new title, adding or updating to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      #
      # @return [void]
      #########################
      def save(admin:)
        Xolo::Server.logger.info "Saving title '#{title}' for admin '#{admin}'"

        # Grab the on-disk state before we
        # update it, so we can compare it to this one
        # as we save to Jamf and Title Editor
        if title_data_file.file?
          Xolo::Server.logger.debug 'Found existing older data, will use for update comparison'
          @prev_title = self.class.load(title)
        end

        # if we don't have one, we are creating a new one,
        # so set these values
        unless @prev_title
          Xolo::Server.logger.debug 'This is a new title, setting creation data'
          @creation_date = Time.now
          @created_by = admin
          Xolo::Server.logger.debug "creation_date: #{creation_date}, created_by: #{created_by}"
        end

        Xolo::Server.logger.debug 'Setting modification data'
        @modification_date = Time.now
        @modified_by = admin
        Xolo::Server.logger.debug "modification_date: #{modification_date}, modified_by: #{modified_by}"

        save_to_file
        save_to_title_editor
        # TODO: create or update in Jamf
        # save_to_jamf
      end

      # Save our current data out to our JSON data file
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_to_file
        title_dir.mkpath
        Xolo::Server.logger.debug "Saving local data to: #{title_data_file}"

        title_data_file.pix_atomic_write to_json
      end

      # Create or update this title in the title editor
      #
      # @return [void]
      #######################
      def save_to_title_editor
        cnx = title_editor_cnx

        # update
        if self.class.in_title_editor?(title, cnx: cnx)
          update_in_title_editor(cnx)

        # create
        else
          create_in_title_editor(cnx)
        end
      ensure
        cnx&.disconnect
      end

      # Create a new title in the title editor
      #
      # @param cnx [Windoo::Connection] The title editor connection
      # @return [void]
      ##########################
      def create_in_title_editor(cnx)
        new_title = Windoo::SoftwareTitle.create(
          id: title,
          name: display_name,
          publisher: publisher,
          appName: app_name,
          bundleId: app_bundle_id,
          currentVersion: NEW_TITLE_CURRENT_VERSION,
          cnx: cnx
        )
        # TODO: add ExtAttr (version script) and requirements
      end

      # Update title in the title editor
      #
      # @param cnx [Windoo::Connection] The title editor connection
      # @return [void]
      ##########################
      def update_in_title_editor(cnx)
        title_in_title_editor = Windoo::SoftwareTitle.fetch id: title, cnx: cnx

        ATTRIBUTES.each do |attr, deets|
          next unless deets[:title_editor_attribute]

          new_val = send(attr)
          next if new_val == @prev_title.send(attr)

          title_in_title_editor.send "#{title_in_title_editor}=", new_val
        end

        # TODO: update ExtAttr (version script) and requirements
      end

      # Delete the title and all of its version
      # @return [void]
      ##########################
      def delete
        # TODO: delete from Jamf and the Title Editor first

        title_dir.rmtree
      end

    end # class Title

  end # module Admin

end # module Xolo
