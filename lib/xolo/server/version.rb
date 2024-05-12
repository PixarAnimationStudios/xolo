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

      include Xolo::Server::Mixins::JamfProVersion
      include Xolo::Server::Mixins::TitleEditorVersion

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
        version_dir(title).mkpath
        version_dir(title).children
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

      # @param patch_id [String] the id number of the patch we are looking for
      # @pararm cnx [Windoo::Connection] The Title Editor connection to use
      # @return [Boolean] Does the given patch exist in the Title Editor?
      ###############################
      def self.in_ted?(patch_id, cnx:)
        Windoo::Patch.all_ids(cnx: cnx).include? patch_id
      end

      # Attributes
      ######################
      ######################

      # The sinatra session that instantiates this version
      attr_writer :session

      # The Windoo::Patch#patchId
      attr_accessor :ted_id_number

      # Jamf object names start with this
      attr_reader :jamf_obj_name_pfx

      # Jamf auto-install policies are named this
      attr_reader :jamf_auto_install_policy_name

      # Jamf manual install policies are named this
      attr_reader :jamf_manual_install_policy_name
      # the custom trigger is the same
      alias jamf_manual_install_trigger jamf_manual_install_policy_name

      # Jamf Patch Policies are named this
      attr_reader :jamf_patch_policy_name

      # The Jamf::Package object has this jamf id
      attr_reader :jamf_pkg_id

      # Constructor
      ######################
      ######################

      # Set more attrs
      def initialize(data_hash)
        super
        # no need to store these, just generate them now
        @jamf_obj_name_pfx = "#{JAMF_OBJECT_NAME_PFX}#{title}-#{version}"
        @jamf_pkg_name ||= @jamf_obj_name_pfx
        @jamf_auto_install_policy_name = "#{jamf_obj_name_pfx}#{JAMF_POLICY_NAME_AUTO_INSTALL_SFX}"
        @jamf_manual_install_policy_name = "#{jamf_obj_name_pfx}#{JAMF_POLICY_NAME_MANUAL_INSTALL_SFX}"

        # we set @jamf_pkg_file when a pkg is uploaded
        # since we don't know until then if its a .pkg or .zip
        # It will be stored in the local data and reloaded as needed

        # These attrs aren't defined in the ATTRIBUTES
        @ted_id_number ||= data_hash[:ted_id_number]
        @jamf_pkg_id ||= data_hash[:jamf_pkg_id]
      end

      # Instance Methods
      ######################
      ######################

      # @return [Xolo::Server::Title] the Title object that holds this version
      ###########################
      def title_object
        return @title_object if @title_object

        @title_object = Xolo::Server::Title.load title
        @title_object.session = session
        @title_object
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
      def ted_cnx
        @ted_cnx ||= super
      end

      # @return [Jamf::Connection] a single Jamf Pro API connection to use for
      #   the life of this instance
      #############################
      def jamf_cnx
        @jamf_cnx ||= super
      end

      # The data file for this version
      # @return [Pathname]
      #########################
      def version_data_file
        self.class.version_data_file title, version
      end

      # @return [Windoo::Patch] The Windoo::Patch object that represents
      #   this version in the title editor
      #############################
      def ted_patch
        @ted_patch ||= ted_title.patches.patch(version)
      end

      # @return [Windoo::SoftwareTitle] The Windoo::SoftwareTitle object that represents
      #   this version's title in the title editor
      #############################
      def ted_title
        @ted_title ||= Windoo::SoftwareTitle.fetch id: title, cnx: ted_cnx
      end

      # override the autogenerated getter, and
      # get this value every time we look at it
      def deployable
        ted_patch&.enabled?
      end

      # Save a new version, adding to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      #
      # @return [void]
      #########################
      def create
        log_info "Creating new version #{version} of title '#{title}' for admin '#{admin}'"

        self.creation_date = Time.now
        self.created_by = admin
        self.status = STATUS_PENDING

        log_debug "creation_date: #{creation_date}, created_by: #{created_by}"
        self.modification_date = Time.now
        self.modified_by = admin
        log_debug "modification_date: #{modification_date}, modified_by: #{modified_by}"

        # save to file here so that we have something to delete if
        # the next couple steps fail
        save_local_data

        create_patch_in_ted
        create_in_jamf

        # save to file again now, because saving to TitleEd and Jamf will
        # add some data
        save_local_data

        # TODO: allow specification of version_order, probably by accepting a value
        # for the 'previous_version'?
        # prepend our version to the version_order array of the title
        log_debug "Updating title version_order, prepending '#{version}'"

        title_object.version_order.unshift version
        title_object.save_local_data
      end

      # Update a this version, updating to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      #
      #
      # TODO: allow specification of version_order, probably by accepting a value
      # for the 'previous_version'?
      #
      # @param new_data [Hash] The new data sent from xadm
      # @return [void]
      #########################
      def update(new_data)
        log_info "Updating version '#{version}' of title '#{title}' for admin '#{admin}'"

        self.modification_date = Time.now
        self.modified_by = admin
        log_debug "modification_date: #{modification_date}, modified_by: #{modified_by}"

        update_patch_in_ted new_data

        # TODO:  update in Jamf if needed

        # update local data before saving back to file
        ATTRIBUTES.each do |attr, deets|
          next if deets[:read_only]

          new_val = new_data[attr]
          old_val = send(attr)
          next if new_val == old_val

          log_debug "Updating Xolo attribute '#{attr}': #{old_val} -> #{new_val}"
          send "#{attr}=", new_val
        end

        # save to file last, because saving to TitleEd and Jamf will
        # add some data
        save_local_data

        # TODO: upload any new pk=g
      end

      # Save our current data out to our JSON data file
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_local_data
        self.class.version_dir(title).mkpath

        file = version_data_file
        log_debug "Saving local version data to: #{file}"
        file.pix_atomic_write to_json
      end

      # Delete the title and all of its version
      # @param update_title [Boolean] Update the title for this version to
      # know the version is gone. Set this to false when the title itself
      # is being deleted and calling this method.
      #
      # @return [void]
      ##########################
      def delete(update_title: true)
        delete_patch_from_ted
        delete_version_from_jamf

        # remove from the title's list of versions
        if update_title
          title_object.version_order.delete version
          title_object.save_local_data
        end

        # delete the local data
        log_info "Deleting local data for version '#{version}' of title '#{title}'"
        version_data_file.delete
      end

      # Add more data to our hash
      ###########################
      def to_h
        hash = super

        # These attrs aren't defined in the ATTRIBUTES
        hash[:jamf_pkg_id] = jamf_pkg_id
        hash[:ted_id_number] = ted_id_number

        hash
      end

    end # class Version

  end # module Server

end # module Xolo
