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

      # If a title has a 'version_script'
      # the the contents are stored in the title dir
      # in a file with this name
      VERSION_SCRIPT_FILENAME = 'version-script'

      # In the TitleEditor, the version script is
      # stored as an Extension Attribute - each title can
      # only have one.
      # and it nees a 'key', which is used to indicate the
      # EA in various criteria.
      # The key is this value as a suffix on the title
      # so for title 'foobar', it is 'foobar-xolo-version-ea'
      # That value is also used as the display name
      TITLE_EDITOR_EA_KEY_SUFFIX = '-xolo-version-ea'

      # When we are given a Self Service icon for the title,
      # we might not be ready to upload it to jamf, cuz until we
      # have a version to pilot, there's nothing IN jamf.
      # So we always store it locally in this file inside the
      # title dir. The extension from the original file will be
      # appended, e.g. '.png'
      SELF_SERVICE_ICON_FILENAME = 'self-service-icon'

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

      # @return [String] The key and display name of a version script stored
      #   in the title editor as the ExtAttr for a given title
      #####################
      def self.ted_ea_key(title)
        "#{title}#{TITLE_EDITOR_EA_KEY_SUFFIX}"
      end

      # The title dir for a given title on the server,
      # which may or may not exist.
      #
      # @pararm title [String] the title we care about
      #
      # @return [Pathname]
      #####################
      def self.title_dir(title)
        TITLES_DIR + title
      end

      # The the local JSON file containing the current values
      # for the given title
      #
      # @pararm title [String] the title we care about
      #
      # @return [Pathname]
      #####################
      def self.title_data_file(title)
        title_dir(title) + "#{title}.json"
      end

      # @pararm title [String] the title we care about
      #
      # @return [Pathname] The the local file containing the code of the version script
      #####################
      def self.version_script_file(title)
        title_dir(title) + VERSION_SCRIPT_FILENAME
      end

      # @pararm title [String] the title we care about
      #
      # @return [Pathname] The the local file containing the self-service icon
      #####################
      def self.ssvc_icon_file(title)
        title_dir(title) + SELF_SERVICE_ICON_FILENAME
      end

      # @pararm title [String] the title we care about
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
      attr_accessor :ted_id_number

      # Constructor
      ######################
      ######################

      # Set more attrs
      def initialize(data_hash)
        super
        @ted_id_number ||= data_hash[:ted_id_number]
        @version_order ||= []
      end

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
      def ted_cnx
        @ted_cnx ||= super
      end

      # @return [Jamf::Connection] a single Jamf Pro API connection to use for
      #   the life of this instance
      #############################
      def jamf_cnx
        @jamf_cnx ||= super
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

      # @return [Pathname] The the local file containing the code of the version script
      #####################
      def version_script_file
        self.class.version_script_file title
      end

      # @return [Pathname] The the local file containing the self-service icon
      #####################
      def ssvc_icon_file
        self.class.ssvc_icon_file title
      end

      # @return [String] The content of the version_script, if any
      ####################
      def version_script_content
        return if version_script.pix_blank?

        version_script == Xolo::ITEM_UPLOADED ? version_script_file.read : varsion_script
      end

      # @return [Windoo::SoftwareTitle] The Windoo::SoftwareTitle object that represents
      #   this title in the title editor
      #############################
      def ted_title
        @ted_title ||= Windoo::SoftwareTitle.fetch id: title, cnx: ted_cnx
      end

      # @return [String] The key and display name of a version script stored
      #   in the title editor as the ExtAttr for this title
      #####################
      def ted_ea_key
        self.class.ted_ea_key title
      end

      # For a Title to be enabled in the Title Editor, it needs at least a requirement criterion
      # and one enabled patch. Xolo enforces the requirement when the title is created, so from
      # the title editor's view it should be OK as soon as there's an enabled patch.
      #
      # So once we have that, this method is called to enable the title.
      #
      # @param title [Xolo::Server::Title] the Title to enable in the Title Editor
      #
      # @return [void]
      ##############################
      def enable_ted_title
        return if ted_title.enabled?

        log_debug "Title Editor: Enabling SoftwareTitle '#{title}'"
        ted_title.enable
      end

      # For a title to be enabled, it must
      # - have at least one enabled patch
      # - have at least one requirement
      #
      # @return [Boolean] is this title enabled?
      ########################
      # def enabled?
      #   ted_title.enabled?
      # end

      # Save a new title, adding to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      #
      # @return [void]
      #########################
      def create
        log_info "Creating new title '#{title}' for admin '#{admin}'"

        self.creation_date = Time.now
        self.created_by = admin
        log_debug "creation_date: #{creation_date}, created_by: #{created_by}"
        self.modification_date = Time.now
        self.modified_by = admin
        log_debug "modification_date: #{modification_date}, modified_by: #{modified_by}"

        create_in_title_editor

        # Nothing to do in Jamf until the first version is created

        # save to file last, because saving to TitleEd and Jamf will
        # add some data
        save_local_data

        # TODO: Deal with VersionScript (TEd ExtAttr + requirement ), or
        # appname & bundleid (TEd requirements)
        # in local file, and TRd

        # TODO: upload any self svc icon
      end

      # Update this title, updating to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      #
      # @param new_data [Hash] The new data sent from xadm
      # @return [void]
      #########################
      def update(new_data)
        log_info "Updating title '#{title}' for admin '#{admin}'"

        delete_version_script_file unless new_data[:version_script]

        self.modification_date = Time.now
        self.modified_by = admin
        log_debug "modification_date: #{modification_date}, modified_by: #{modified_by}"

        update_in_title_editor new_data

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

        # TODO: Deal with VersionScript (TEd ExtAttr + requirement ), or
        # appname & bundleid (TEd requirements)
        # in local file, and TRd, and... jamf?

        # TODO: upload any self svc icon
      end

      # Save our current data out to our JSON data file
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_local_data
        title_dir.mkpath
        save_version_script

        # if we've ever uploaded an icon, the last one is still there
        # so set this appropriately
        if self_service_icon.pix_blank? && title_dir.children.any? do |f|
             f.basename.to_s.start_with? SELF_SERVICE_ICON_FILENAME
           end
          self.self_service_icon = Xolo::ITEM_UPLOADED
        end

        file = title_data_file
        log_debug "Saving local data to: #{file}"
        file.pix_atomic_write to_json
      end

      # Save our current version script out to our local file,
      # but only if we aren't using app_name and app_bundle_id
      #
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_version_script
        return if app_name && app_bundle_id
        return if version_script == Xolo::ITEM_UPLOADED

        file = version_script_file
        log_debug "Saving version_script to: #{file}"
        file.pix_atomic_write version_script

        # the json file only stores 'uploaded' in the version_script
        # attr.
        self.version_script = Xolo::ITEM_UPLOADED
      end

      # Save the self_service_icon from the upload tmpfile
      # to the file in the data dir.
      #
      # This is run by the upload route, not the
      # create or update methods here. xadm
      # does the upload after creating or updating the title
      #
      # @param tempfile [Pathname] The path to the uploaded tmp file
      #
      # @return [void]
      ##########################
      def save_ssvc_icon(tempfile)
        # at this point, self_service_icon will contain the file path
        # on the admin's local machine. So get the
        # basename from it.
        orig_filename = Pathname.new(self_service_icon).basename

        # here's where we'll store it on the server
        file = ssvc_icon_file
        ext_for_file = self_service_icon.split(Xolo::DOT).last

        file = file.parent + "#{file.basename}.#{ext_for_file}" if ext_for_file

        # delete any previous icon files
        old_icons = title_dir.children.select { |c| c.basename.to_s.start_with? SELF_SERVICE_ICON_FILENAME }
        unless old_icons.empty?
          old_icons.each do |oi|
            oi.delete
            log_debug "Deleted older icon file: #{oi.basename}"
          end
        end
        title_dir.children.each { |c| c.delete if c.basename.to_s.start_with? SELF_SERVICE_ICON_FILENAME }
        log_debug "Saving self_service_icon '#{orig_filename}' to: #{file}"
        tempfile.rename file

        # the json file only stores 'uploaded' in the self_service_icon
        # attr.
        self.self_service_icon = Xolo::ITEM_UPLOADED
        save_local_data
      end

      # Delete the version script file
      #
      # @return [void]
      ##########################
      def delete_version_script_file
        return unless version_script_file.file?

        log_debug "Deleting version script file: #{version_script_file}"

        version_script_file.delete
      end

      # Create a new title in the title editor
      #
      # @return [void]
      ##########################
      def create_in_title_editor
        log_info "Title Editor: Creating SoftwareTitle '#{title}'"
        new_ted_title = Windoo::SoftwareTitle.create(
          id: title,
          name: display_name,
          publisher: publisher,
          appName: app_name,
          bundleId: app_bundle_id,
          currentVersion: NEW_TITLE_CURRENT_VERSION,
          cnx: ted_cnx
        )

        update_ted_requirements new_ted_title

        self.ted_id_number = new_ted_title.softwareTitleId
      end

      # Update title in the title editor
      #
      # TODO: If title switches from versionscript to app info, all patch components must be updated
      #
      #
      # @param new_data [Hash] The new data sent from xadm
      # @return [void]
      ##########################
      def update_in_title_editor(new_data)
        log_info "Title Editor: Updating SoftwareTitle '#{title}'"

        ATTRIBUTES.each do |attr, deets|
          ted_attribute = deets[:ted_attribute]
          next unless ted_attribute

          new_val = new_data[attr]
          old_val = send(attr)
          next if new_val == old_val

          # These changes happen in real time on the Title Editor server
          log_debug "Title Editor: Updating title attribute '#{ted_attribute}': #{old_val} -> #{new_val}"
          ted_title.send "#{ted_attribute}=", new_val
        end

        update_ted_requirements ted_title, new_data

        self.ted_id_number = ted_title.softwareTitleId
      end

      # Add or update the requirements in the TItle Editor title.
      # Requirements are criteria indicating that this title (any version)
      # is installed on a client machine.
      #
      # If the Xolo Title has app_name and app_bundle_id defined,
      # they are used as the criteria.
      #
      # If the Xolo Title as a version_script defined, it returns
      # either an empty value, or the version installed on the client
      # it is added to the Title Editor title and used both as the
      # requirement criterion (not empty) and as a Patch Component
      # criterion for versions (the value contains the version)
      # TODO: If title switches from versionscript to app info, all patch components must be updated
      #
      #
      # @param ted_title [Windoo::SoftwareTitle] the TEd title we are changing
      #
      # @return [void]
      ######################
      def update_ted_requirements(ted_title, new_data = nil)
        log_debug "Title Editor: Setting Requirements for title '#{title}'"

        # delete the current requirements
        ted_title.requirements.delete_all_criteria

        req_app_name = new_data ? new_data[:app_name] : app_name
        req_app_bundle_id = new_data ? new_data[:app_bundle_id] : app_bundle_id
        req_ea_script = new_data ? new_data[:version_script] : version_script

        if req_app_name && req_app_bundle_id
          update_ted_app_requirements(
            ted_title,
            req_app_name: req_app_name,
            req_app_bundle_id: req_app_bundle_id
          )

        elsif req_ea_script
          update_ted_ea_requirements ted_title, req_ea_script: req_ea_script

        else
          msg = 'No version_script, nor app_name & app_bundle_id - Cannot create Title Editor Title Requirements'
          log_error msg
          raise Xolo::MissingDataError, msg
        end
      end

      # Update the Title Editor Title EA  and requireents
      # with the current version_script
      #
      # these changes happen immediately on the server
      #
      # @param ted_title [Windoo::SoftwareTitle] the TEd title we are changing
      #
      # @param ea_script [String] the code of the script.
      #
      # @return [void]
      ####################
      def update_ted_ea_requirements(ted_title, req_ea_script:)
        log_debug "Title Editor: Setting ExtensionAttribute version_script and Requirement Criteria for title '#{title}'"

        # delete and recreate the EA
        ted_title.delete_extensionAttribute

        ted_title.add_extensionAttribute(
          key: ted_ea_key,
          displayName: ted_ea_key,
          script: req_ea_script
        )

        # add a requirement criterion using the EA
        # Any value in the EA means the title is installed
        # (the value will be the version that is installd)
        ted_title.requirements.add_criterion(
          type: 'extensionAttribute',
          name: ted_ea_key,
          operator: 'matches regex',
          value: '.+'
        )
      end

      # Update the Title Editor Title Requirements with app name and bundle id.
      # these changes happen immediately on the server
      #
      # @param ted_title [Windoo::SoftwareTitle] the TEd title we are changing
      #
      # @return [void]
      ####################
      def update_ted_app_requirements(ted_title, req_app_name:, req_app_bundle_id:)
        log_debug "Title Editor: Setting App-based Requirement Criteria for title '#{title}'"

        ted_title.requirements.add_criterion(
          name: 'Application Title',
          operator: 'is',
          value: app_name
        )

        ted_title.requirements.add_criterion(
          name: 'Application Bundle ID',
          operator: 'is',
          value: app_bundle_id
        )

        return unless ted_title.extensionAttribute

        log_debug "Title Editor: Deleting unused Extension Attribute for title '#{title}'"
        ted_title.delete_extensionAttribute
      end

      # Delete the title and all of its version
      # @return [void]
      ##########################
      def delete
        delete_from_title_editor

        # TODO: delete in jamf
        log_info "Deleting local data for title '#{title}'"
        title_dir.rmtree
      end

      # Delete from the title editor
      # @return [Integer] title editor id number
      ###########################
      def delete_from_title_editor
        log_info "Title Editor: Deleting SoftwareTitle '#{title}'"

        ted_title.delete
      rescue Windoo::NoSuchItemError
        ted_id_number
      end

      # Add more data to our hash
      ###########################
      def to_h
        self.enabled = ted_title.enabled?
        hash = super
        hash[:ted_id_number] = ted_id_number
        hash
      end

    end # class Title

  end # module Admin

end # module Xolo
