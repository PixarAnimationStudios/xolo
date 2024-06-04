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

    # A Title in Xolo, as used on the server
    #
    # NOTE be sure to only instantiate these using the
    # servers 'instantiate_title' method, or else
    # they might not have all the correct innards
    class Title < Xolo::Core::BaseClasses::Title

      # Mixins
      #############################
      #############################

      include Xolo::Server::Helpers::JamfPro
      include Xolo::Server::Helpers::TitleEditor
      include Xolo::Server::Helpers::Log

      include Xolo::Server::Mixins::TitleJamfAccess
      include Xolo::Server::Mixins::TitleTedAccess

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
      # and it needs a 'key', which is used to indicate the
      # EA in various criteria, and is the EA name in Jamf/
      # The key is this value as a prefix on the title
      # so for title 'foobar', it is 'xolo-version-ea-foobar'
      # That value is also used as the display name
      TITLE_EDITOR_EA_KEY_PREFIX = 'xolo-version-ea-'

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
        "#{TITLE_EDITOR_EA_KEY_PREFIX}#{title}"
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
        title_dir(title).children.select { |c| c.basename.to_s.start_with? SELF_SERVICE_ICON_FILENAME }.first
      end

      # Instantiate from the local JSON file containing the current values
      # for the given title
      #
      # NOTE: All instantiation should happen using the #instantiate_title method
      # in the server app instance. Please don't call this method directly
      #
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
      def self.in_ted?(title, cnx:)
        Windoo::SoftwareTitle.all_ids(cnx: cnx).include? title
      end

      # Attributes
      ######################
      ######################

      # The instance of Xolo::Server::App that instantiated this
      # title object. This is how we access things that are available in routes
      # and helpers, like the single Jamf and TEd
      # connections for this App instance.
      attr_accessor :server_app_instance

      # The sinatra session that instantiates this title
      #  attr_writer :session

      # The Windoo::SoftwareTitle#softwareTitleId
      attr_accessor :ted_id_number

      # when applying updates, the new data is stored
      # here so it can be accessed by update-methods
      # and compared to the current instanace values
      # both for updating the title, and the versions
      attr_reader :new_data_for_update

      # version_order is defined in ATTRIBUTES
      alias versions version_order

      # Constructor
      ######################
      ######################

      # NOTE: be sure to only instantiate these using the
      # servers 'instantiate_title' method, or else
      # they might not have all the correct innards
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
        server_app_instance&.session || {}
        # @session ||= {}
      end

      # @return [String]
      ###################
      def admin
        session[:admin]
      end

      # Append a message to the progress stream file,
      # optionally sending it also to the log
      #
      # @param message [String] the message to append
      # @param log [Symbol] the level at which to log the message
      #   one of :debug, :info, :warn, :error, :fatal, or :unknown.
      #   Default is nil, which doesn't log the message at all.
      #
      # @return [void]
      ###################
      def progress(msg, log: :debug)
        server_app_instance.progress msg, log: log
      end

      # @return [Windoo::Connection] a single Title Editor connection to use for
      #   the life of this instance
      #############################
      def ted_cnx
        server_app_instance.ted_cnx
      end

      # @return [Jamf::Connection] a single Jamf Pro API connection to use for
      #   the life of this instance
      #############################
      def jamf_cnx
        server_app_instance.jamf_cnx
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

      # @return [Pathname] The the local file containing the self-service icon
      #####################
      def ssvc_icon_file
        self.class.ssvc_icon_file title
      end

      # @return [Pathname] The the local file containing the code of the version script
      #####################
      def version_script_file
        self.class.version_script_file title
      end

      # @return [String] The string contents of the version_script, if any
      ####################
      def version_script_contents
        # the value will be
        # - nil (no script used),
        # - a script, that will replace any existing,
        # - or Xolo::ITEM_UPLOADED, meaning use the one we have saved on disk

        # if we have incoming data, that's what we care about
        # otherwise we use our current value
        curr_script = @new_data_for_update ? @new_data_for_update[:version_script] : version_script
        return if curr_script.pix_empty?

        curr_script == Xolo::ITEM_UPLOADED ? version_script_file.read : curr_script
      end

      # @return [Windoo::SoftwareTitle] The Windoo::SoftwareTitle object that represents
      #   this title in the title editor
      #############################
      def ted_title(refresh: false)
        @ted_title = nil if refresh
        @ted_title ||= Windoo::SoftwareTitle.fetch id: title, cnx: ted_cnx
      end

      # @return [String] The key and display name of a version script stored
      #   in the title editor as the ExtAttr for this title
      #####################
      def ted_ea_key
        self.class.ted_ea_key title
      end

      # instantiate a version if this title
      #
      # @return [Xolo::Server::Version]
      ########################
      def version_object(version)
        log_debug "Instantiating version #{version} from Title instance #{title}"
        server_app_instance.instantiate_version(title: title, version: version)
      end

      # @return [Array<Xolo::Server::Version>] An array of all current version objects
      #   NOTE: This might not be wise if hundreds of versions.
      ########################
      def version_objects(refresh: false)
        version_order.map { |v| version_object v }
      end

      # Save a new title, adding to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      #
      # @return [void]
      #########################
      def create
        self.creation_date = Time.now
        self.created_by = admin
        log_debug "creation_date: #{creation_date}, created_by: #{created_by}"
        self.modification_date = Time.now
        self.modified_by = admin
        log_debug "modification_date: #{modification_date}, modified_by: #{modified_by}"

        create_title_in_ted

        # Nothing to do in Jamf until the first version is created

        # save to file last, because saving to TitleEd and Jamf will
        # add some data
        progress 'Saving title data to Xolo server'
        save_local_data

        # ssvc icon is uploaded in a separate process, and the
        # title data file will be updated as needed then.
      end

      # Update this title, updating to the
      # local filesystem, Jamf Pro, and the Title Editor,
      # and applying any changes to existing versions as needed.
      #
      # @param new_data [Hash] The new data sent from xadm
      # @return [void]
      #########################
      def update(new_data)
        # make the new data availble as needed,
        # for methods to compare the incoming new data
        # with the existing instance data
        @new_data_for_update = new_data
        log_info "Updating title '#{title}' for admin '#{admin}'"

        self.modification_date = Time.now
        self.modified_by = admin

        # Do ted before doing things in Jamf
        update_title_in_ted
        update_title_in_jamf

        # Don't do this until we no longer need to use
        # @new_data_for_update for comparison with our
        # 'old' insance values.
        update_local_instance_values

        # save to file last, because saving to TitleEd and Jamf may
        # add or change some data
        save_local_data

        # even if we already have a version script, the new data should
        # contain Xolo::ITEM_UPLOADED. If its nil, we shouldn't
        # have one at all and should remove the old one.
        delete_version_script_file unless new_data_for_update[:version_script]

        # nothing to do below here if we have no versions yet
        return if versions.pix_empty?

        # loop thru versions and apply changes
        #
        # Since @new_data_for_update is no longer valid
        # for comparisons, the prev. methods should have
        # set flags indicating anything we need to do to
        # the versions. E.g.
        # @need_to_set_version_patch_components
        # or
        # @need_to_update_target_group
        update_versions_for_title_changes

        # changing the ted patches probably disabled the title
        # so re-enable it
        reenable_ted_title

        # Do This at the end - after all the versions/patches have been updated.
        # Jamf won't see the need for re-acceptance until after the title
        # (and at least one patch) have been re-enabled.
        #
        # jamf_ea_matches_version_script is a failsafe:
        # Does our version script match what jamf sees as the EA?
        # if not, we might need to (re)accept the version-script EA
        # if its true or nil, no need to re-accept
        # if its false, jamf should eventually need us to re-accept
        #
        accept_xolo_ea_in_jamf if @need_to_accept_xolo_ea_in_jamf || jamf_ea_matches_version_script? == false

        # any new self svc icon will be uploaded in a separate process
        # and the local data will be updated again then
      end # update

      # Update our instance attributes with any new data before
      # saving the changes back out to the file system
      # @return [void]
      ###########################
      def update_local_instance_values
        # update instance data with new data before writing out to the filesystem.
        # Do this last so that the instance values can be compared to
        # @new_data_for_update in the steps above.
        # Also, those steps might have updated some server-specific attributes
        # which will be saved to the file system as well.
        ATTRIBUTES.each do |attr, deets|
          # make sure these are updated elsewhere if needed,
          # e.g. modification data.
          next if deets[:read_only]

          new_val = new_data_for_update[attr]
          old_val = send(attr)
          next if new_val == old_val

          log_debug "Updating Xolo Title attribute '#{attr}': '#{old_val}' -> '#{new_val}'"
          send "#{attr}=", new_val
        end
        # update any other server-specific attributes here...
      end

      # If any title changes require updates to existing versions in either
      # the title editor, or Jamf, this loops thru the versions and applies
      # them
      #
      # This should happen after the incoming changes have been applied to this instance
      #
      # Ted Stuff
      # - swap version-script / app-based component if needed
      # - re-enable all patches
      # - re-enable the title
      # Jamf Stuff
      # - update any policy scopes
      # - update any policy SSvc settings
      #
      # @return [void]
      ############################
      def update_versions_for_title_changes
        vobjs = version_objects
        return if vobjs.empty?

        vobjs.each do |vers_obj|
          update_ted_patch_component_for_version(vers_obj) if @need_to_set_version_patch_components

          vers_obj.update_pilot_groups(ttl_obj: self) if @need_to_update_pilot_groups
          vers_obj.update_release_groups(ttl_obj: self)  if @need_to_update_release_groups
          vers_obj.update_excluded_groups(ttl_obj: self) if @need_to_update_excluded_groups

          # turn self service on or off
          vers_obj.update_ssvc(ttl_obj: self) if @need_to_update_ssvc

          # update ssvc category if needed, and if self_services is on
          vers_obj.update_ssvc_category(ttl_obj: self) if @need_to_update_ssvc_category && self_service
        end
      end

      # Save our current data out to our JSON data file
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_local_data
        title_dir.mkpath
        save_version_script

        # do we have a stored self service icon?
        self.self_service_icon = ssvc_icon_file ? Xolo::ITEM_UPLOADED : nil

        file = title_data_file
        log_debug "Saving local title data to: #{file}"
        file.pix_atomic_write to_json
      end

      # Save our current version script out to our local file,
      # but only if we aren't using app_name and app_bundle_id
      # and only if it's changed
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_version_script
        return if app_name && app_bundle_id
        return if version_script == Xolo::ITEM_UPLOADED

        file = version_script_file
        return if file&.readable? && version_script.chomp == file.read.chomp

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
      # create or update methods here.
      # xadm does the upload after creating or updating the title
      #
      # @param tempfile [Pathname] The path to the uploaded tmp file
      #
      # @return [void]
      ##########################
      def save_ssvc_icon(tempfile, orig_filename)
        # here's where we'll store it on the server
        ext_for_file = orig_filename.split(Xolo::DOT).last
        new_basename =  "#{SELF_SERVICE_ICON_FILENAME}.#{ext_for_file}"
        new_icon_file = title_dir + new_basename

        # delete any previous icon files
        existing_icon_file = ssvc_icon_file
        if existing_icon_file&.file?
          log_debug "Deleting older icon file: #{existing_icon_file.basename}"
          existing_icon_file.delete
        end

        log_debug "Saving self_service_icon '#{orig_filename}' to: #{new_basename}"
        tempfile.rename new_icon_file

        # the json file only stores 'uploaded' in the self_service_icon
        # attr.
        self.self_service_icon = Xolo::ITEM_UPLOADED
        save_local_data
      end

      # If we have any versions, and we are using self service,
      # update all relevant policies with a newly-uploaded icon
      #
      # @return [void]
      ###################################
      def update_ssvc_icon_in_version_policies
        return unless self_service
        return if version_order.pix_empty?

        icon_file = ssvc_icon_file
        return unless icon_file

        version_objects.each { |vo| vo.update_ssvc_icon(ttl_obj: self) }
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

      # Delete the title and all of its version
      # @return [void]
      ##########################
      def delete
        progress "Deleting all versions of #{title}...", log: :debug
        version_objects.each do |vers|
          vers.delete update_title: false
        end

        delete_title_from_ted

        delete_title_from_jamf

        progress "Deleting Xolo server data for title '#{title}'", log: :info
        title_dir.rmtree
      end

      # Add more data to our hash
      ###########################
      def to_h
        hash = super
        hash[:ted_id_number] = ted_id_number
        hash
      end

    end # class Title

  end # module Admin

end # module Xolo
