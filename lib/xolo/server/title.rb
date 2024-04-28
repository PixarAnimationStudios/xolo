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
      include Xolo::Server::Helpers::Log

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

      # TODO: - pass in an ident for the request being processed?
      # (also in the instance method)
      # @return [Logger] quick access to the xolo server logger
      ################
      def self.logger
        Xolo::Server.logger
      end

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
      def self.in_title_editor?(title, cnx:)
        Windoo::SoftwareTitle.all_ids(cnx: cnx).include? title
      end

      # Attributes
      ######################
      ######################

      # The sinatra session that instantiates this title
      attr_writer :session

      # The Windoo::SoftwareTitle#softwareTitleId
      attr_accessor :title_editor_id_number

      # Constructor
      ######################
      ######################

      # Instance Methods
      ######################
      ######################

      # @return [Hash]
      ###################
      def session
        @session ||= {}
      end

      # @return [String]
      ###################
      def admin
        session[:admin]
      end

      # @return [Windoo::Connection] a single Title Editor connection to use for
      #   the life of this instance
      #############################
      def title_editor_cnx
        @title_editor_cnx ||= super
      end

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
      def save
        log_info "Saving title '#{title}' for admin '#{admin}'"

        # Grab the on-disk state before we
        # update it, so we can compare it to this one
        # as we save to Jamf and Title Editor
        if title_data_file.file?
          log_debug 'Found existing older data, will use for update comparison'
          @prev_title = self.class.load(title)
        end

        # if we don't have one, we are creating a new one,
        # so set these values
        unless @prev_title
          log_debug 'This is a new title, setting creation data'
          self.creation_date = Time.now
          self.created_by = admin
          log_debug "creation_date: #{creation_date}, created_by: #{created_by}"
        end

        log_debug 'Setting modification data'
        self.modification_date = Time.now
        self.modified_by = admin
        log_debug "modification_date: #{modification_date}, modified_by: #{modified_by}"

        save_to_title_editor

        # TODO: create or update in Jamf
        # save_to_jamf

        # save to file last, because saving to TitleEd and Jamf will
        # add some data
        save_to_file

        # TODO: Deal with VersionScript (TEd ExtAttr + requirement ), or
        # appname & bundleid (TEd requirements)
        # in local file, and TRd, and... jamf?
      end

      # Save our current data out to our JSON data file
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_to_file
        title_dir.mkpath
        log_debug "Saving local data to: #{title_data_file}"

        title_data_file.pix_atomic_write to_json
      end

      # Create or update this title in the title editor
      #
      # @return [void]
      #######################
      def save_to_title_editor
        # update
        if self.class.in_title_editor?(title, cnx: title_editor_cnx)
          update_in_title_editor

        # create
        else
          create_in_title_editor
        end
      end

      # Create a new title in the title editor
      #
      # @param cnx [Windoo::Connection] The title editor connection
      # @return [void]
      ##########################
      def create_in_title_editor
        log_info "Creating Title Editor SoftwareTitle '#{title}'"
        new_title = Windoo::SoftwareTitle.create(
          id: title,
          name: display_name,
          publisher: publisher,
          appName: app_name,
          bundleId: app_bundle_id,
          currentVersion: NEW_TITLE_CURRENT_VERSION,
          cnx: title_editor_cnx
        )
        self.title_editor_id_number = new_title.softwareTitleId
      end

      # Update title in the title editor
      #
      # @param cnx [Windoo::Connection] The title editor connection
      # @return [void]
      ##########################
      def update_in_title_editor
        # TODO: raise and handle this situation...
        return unless @prev_title

        log_info "Updating Title Editor SoftwareTitle '#{title}'"
        title_in_title_editor = Windoo::SoftwareTitle.fetch id: title, cnx: title_editor_cnx

        ATTRIBUTES.each do |attr, deets|
          title_editor_attribute = deets[:title_editor_attribute]
          next unless title_editor_attribute

          old_val = @prev_title.send(attr)
          new_val = send(attr)
          next if new_val == old_val

          # These changes happen in real time on the Title Editor server
          log_debug "Updating title_editor_attribute '#{title_editor_attribute}': #{old_val} -> #{new_val}"
          title_in_title_editor.send "#{title_editor_attribute}=", new_val
        end

        self.title_editor_id_number = title_in_title_editor.softwareTitleId
      end

      # Delete the title and all of its version
      # @return [void]
      ##########################
      def delete
        delete_from_title_editor

        # TODO: delete in jamf
        title_dir.rmtree
      end

      # Delete from the title editor
      # @return [Integer] title_editor_id_number
      ###########################
      def delete_from_title_editor
        log_info "Deleting Title Editor SoftwareTitle '#{title}'"

        title_in_title_editor = Windoo::SoftwareTitle.fetch id: title, cnx: title_editor_cnx
        title_in_title_editor.delete
      rescue Windoo::NoSuchItemError
        title_editor_id_number
      end

      # Add more data to our hash
      ###########################
      def to_h
        hash = super
        hash[:title_editor_id_number] = title_editor_id_number
        hash
      end

    end # class Title

  end # module Admin

end # module Xolo
