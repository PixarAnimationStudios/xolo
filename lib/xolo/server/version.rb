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

    class Version < Xolo::Core::BaseClasses::Version

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
      #
      # In there will be a 'versions' dir containing json
      # files for each version of the title.
      #
      VERSIONS_DIRNAME = 'versions'

      # Class Methods
      ######################
      ######################

      # @pararm title [String] the title for the version
      # @return [Pathname]  The directory containing version JSON files for a title
      ######################
      def self.version_dir(title)
        Xolo::Server::Title.title_dir(title) + VERSIONS_DIRNAME
      end

      # @pararm title [String] the title for the versions
      # @return [Array<Pathname>] A list of all known versions for a title
      ######################
      def self.version_files(title)
        versions_dir(title).children
      end

      # @pararm title [String] the title for the version
      # @return [Array<String>] A list of all known versions for a title,
      #   just the basenames of all the version files with the extension removed
      ######################
      def self.all_versions(title)
        version_files(title).map { |c| c.basename.to_s.delete_suffix '.json' }
      end

      # The the local JSON file containing the current values
      # for the given version of a title
      #
      # @pararm title [String] the title for the version
      #
      # @pararm version [String] the version we care about
      #
      # @return [Pathname]
      #####################
      def self.version_data_file(title, version)
        version_dir(title) + "#{version}.json"
      end

      # The the local JSON file containing the current values
      # for the given version of a title
      #
      # @pararm title [String] the title for the version
      #
      # @pararm version [String] the version we care about
      #
      # @return [Xolo::Server::Title] load an existing title
      #   from the on-disk JSON file
      ######################
      def self.load(title, version)
        new parse_json(version_data_file(title, version).read)
      end

      # @param title [String] the title we are looking for
      # @pararm cnx [Windoo::Connection] The Title Editor connection to use
      # @return [Boolean] Does the given title exist in the Title Editor?
      ###############################
      def self.in_title_editor?(version, cnx:)
        Windoo::Patch.all_ids(cnx: cnx).include? version
      end

      # Attributes
      ######################
      ######################

      # The sinatra session that instantiates this version
      attr_writer :session

      # The Windoo::Patch#patchId
      attr_accessor :title_editor_id_number

      # Constructor
      ######################
      ######################

      # Set more attrs
      def initialize(data_hash)
        super
        @title_editor_id_number ||= data_hash[:title_editor_id_number]
      end

      # Instance Methods
      ######################
      ######################

      # @return [Xolo::Server::Title] the Title object that holds this version
      ###########################
      def title_object
        @title_object ||= Xolo::Server::Title.load title
      end

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

      # The data file for this version
      # @return [Pathname]
      #########################
      def version_data_file
        self.class.version_data_file title, version
      end

      # Save a new version, adding to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      #
      # @return [void]
      #########################
      def create
        log_info "Creating new version #{version} in title '#{title}' for admin '#{admin}'"

        self.creation_date = Time.now
        self.created_by = admin
        log_debug "creation_date: #{creation_date}, created_by: #{created_by}"
        self.modification_date = Time.now
        self.modified_by = admin
        log_debug "modification_date: #{modification_date}, modified_by: #{modified_by}"

        create_in_title_editor

        # save to file last, because saving to TitleEd and Jamf will
        # add some data
        save_local_data
      end

      # Create a new version in the title editor
      #
      # @return [void]
      ##########################
      def create_in_title_editor
        log_info "Title Editor: Creating Patch '#{version}' for SoftwareTitle '#{title}'"

        title_in_title_editor = Windoo::SoftwareTitle.fetch id: title, cnx: title_editor_cnx

        title_in_title_editor.patches.add_patch(
          version: version,
          minimumOperatingSystem: min_os,
          releaseDate: publish_date,
          reboot: reboot,
          standalone: standalone
        )
        new_patch = title_in_title_editor.patches.patch version

        update_killapps new_patch
        update_capabilites new_patch
        update_components new_patch

        self.title_editor_id_number = new_patch.patchId
      end

      # Update any killapps for this version in the title editor.
      #
      # @param patch [Windoo::Patch] the patch that holds the killapps
      # @return [void]
      ##########################
      def update_killapps(patch)
        # delete the existing
        log_debug "Title Editor: updating killApps for Patch '#{version}' for SoftwareTitle '#{title}'"
        patch.killApps.delete_all_killaps

        # Add the current ones back in
        killapps.each do |ka_str|
          name, bundleid = ka_str.split(Xolo::SEMICOLON_SEP_RE)
          log_debug "Title Editor: Setting killApp '#{ka_str}' for Patch '#{version}' for SoftwareTitle '#{title}'"

          patch.killApps.add_killApp(
            appName: name,
            bundleId: bundleid
          )
        end
      end

      # Update the capabilities for this version in the title editor.
      # This is a collection of criteria that define which computers
      # can install this version.
      #
      # At the very least we enforce the required minimum OS.
      # and optional maximim OS.
      #
      # TODO: Allow xadm to specify other capability criteria?
      #
      # @param patch [Windoo::Patch] the patch for which we are defining capabilities
      # @return [void]
      ##########################
      def update_capabilites(patch)
        log_debug "Title Editor: updating capabilities for Patch '#{version}' for SoftwareTitle '#{title}'"

        # delete the existing
        patch.capabilities.delete_all_criteria

        # Add the current ones back in

        # min os
        log_debug "Title Editor: setting min_os capability for Patch '#{version}' for SoftwareTitle '#{title}'"
        patch.capabilities.add_criterion(
          name: 'Operating System Version',
          operator: 'greater than or equal',
          value: min_os
        )

        return unless max_os

        # max os
        log_debug "Title Editor: setting max_os capability for Patch '#{version}' for SoftwareTitle '#{title}'"
        patch.capabilities.add_criterion(
          name: 'Operating System Version',
          operator: 'less than or equal',
          value: max_os
        )
      end

      # Update the component criteria for this version in the title editor.
      #
      # This is a collection of criteria that define which computers
      # have this version installed
      #
      # TODO: allow xadm to define more complex critera?
      #
      # @param patch [Windoo::Patch] the patch for which we are defining the component criteria
      # @return [void]
      ##########################
      def update_component(patch)
        log_debug "Title Editor: updating component criteria for Patch '#{version}' for SoftwareTitle '#{title}'"

        # delete the existing component, and its criteria
        patch.delete_component

        # create a new one
        patch.add_component name: title, version: version
        comp = patch.component

        # Are we using the 'version_script' (aka the EA for the title)
        if title_object.version_script
          log_debug "Title Editor: setting EA-based component criteria for Patch '#{version}' for SoftwareTitle '#{title}'"

          comp.criteria.add_criterion(
            type: 'extensionAttribute',
            name: title_object.title_editor_ea_key,
            operator: 'is',
            value: version
          )

        # If not, we are using the app name and bundle ID
        # and version
        else
          log_debug "Title Editor: setting App-based component criteria for Patch '#{version}' for SoftwareTitle '#{title}'"

          comp.criteria.add_criterion(
            name: 'Application Title',
            operator: 'is',
            value: title_object.app_name
          )

          comp.criteria.add_criterion(
            name: 'Application Bundle ID',
            operator: 'is',
            value: title_object.app_bundle_id
          )

          comp.criteria.add_criterion(
            name: 'Application Version',
            operator: 'is',
            value: version
          )
        end
      end

      # Save our current data out to our JSON data file
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_local_data
        self.class.version_dir(title).mkpath

        file = version_data_file
        log_debug "Saving local data to: #{file}"
        file.pix_atomic_write to_json
      end

    end # class Version

  end # module Server

end # module Xolo
