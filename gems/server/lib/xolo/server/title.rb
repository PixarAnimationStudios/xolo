# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.

# frozen_string_literal: true

# main module
module Xolo

  module Server

    # A Title in Xolo, as used on the server
    #
    # The code in this file mostly deals with the data on the Xolo server itself, and
    # general methods for manipulating the title.
    #
    # Code for interacting with the Title Editor and Jamf Pro are in the helpers and mixins.
    #
    # NOTE be sure to only instantiate these using the
    # servers 'instantiate_title' method, or else
    # they might not have all the correct innards
    #
    class Title < Xolo::Core::BaseClasses::Title

      # Mixins
      #############################
      #############################

      include Xolo::Server::Helpers::JamfPro
      include Xolo::Server::Helpers::TitleEditor
      include Xolo::Server::Helpers::Log
      include Xolo::Server::Helpers::Notification

      include Xolo::Server::Mixins::Changelog
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

      # If a title is uninstallable, it will
      # have a script in Jamf, which is also saved in this file
      # on the xolo server.
      UNINSTALL_SCRIPT_FILENAME = 'uninstall-script'

      # In the TitleEditor, the version script is
      # stored as an Extension Attribute - each title can
      # only have one.
      # and it needs a 'key', which is the name used to indicate the
      # EA in various criteria, and is the EA name in Jamf Patch.
      # The key is this value as a prefix on the title
      # so for title 'foobar', it is 'xolo-foobar'
      # That value is also used as the display name
      TITLE_EDITOR_EA_KEY_PREFIX = Xolo::Server::JAMF_OBJECT_NAME_PFX

      # The EA from the title editor, which is used in Jamf Patch
      # cannot, unfortunately, be used as a criterion in normal
      # smart groups or advanced searches.
      # Since we need a smart group containing all macs with any
      # version of the title installed, we need a second copy of the
      # EA as a 'normal' EA.
      #
      # (That group is used as an exclusion to any auto-install initial-
      # install policies, so that those policies don't stomp on the matching
      # Patch Policies)
      #
      # The 'duplicate' EA is named the same as the Titled Editor key
      # (see TITLE_EDITOR_EA_KEY_PREFIX) with this suffix added.
      # So for the Title Editor key 'xolo-<title>', we'll also have
      # a matching normal EA called 'xolo-<title>-installed-version'
      JAMF_NORMAL_EA_NAME_SUFFIX = '-installed-version'

      JAMF_INSTALLED_GROUP_NAME_SUFFIX = '-installed'
      JAMF_FROZEN_GROUP_NAME_SUFFIX = '-frozen'

      JAMF_UNINSTALL_SUFFIX = '-uninstall'
      JAMF_EXPIRE_SUFFIX = '-expire'

      # the expire policy will run this client command,
      # appending the title
      # We don't specify a full path so that localized installations
      # will work as long as its in roots default path
      # e.g. /usr/local/bin  vs /usr/local/pixar/bin
      CLIENT_EXPIRE_COMMAND = 'xolo expire'

      # When we are given a Self Service icon for the title,
      # we might not be ready to upload it to jamf, cuz until we
      # have a version to pilot, there's nothing IN jamf.
      # So we always store it locally in this file inside the
      # title dir. The extension from the original file will be
      # appended, e.g. '.png'
      SELF_SERVICE_ICON_FILENAME = 'self-service-icon'

      # The JPAPI endpoint for Patch Titles.
      #
      # ruby-jss still uses the Classic API for Patch Titles, and won't
      # by migrated to JPAPI until Jamf fully implements all aspects of
      # patch management to JPAPI. As of this writing, that's not the case.
      # But, the JPAPI endpoint for Patch Title Reporting returns more
      # detailed data than the Classic API, so we use it here, and will
      # keep using it as we move forward.
      #
      # This is the top-level endpoint for all patch titles,
      # see JPAPI_PATCH_REPORT_RSRC for the reporting endpoint below it.
      #
      # TODO: Remove this and update relevant methods when ruby-jss
      # is updated to use JPAPI for Patch Titles..
      JPAPI_PATCH_TITLE_RSRC = 'v2/patch-software-title-configurations'

      # The JPAPI endpoint for patch reporting.
      # The JPAPI_PATCH_TITLE_RSRC is appended with "/<id>/#{JPAPI_PATCH_REPORT_RSRC}"
      # to get the URL for the patch report for a specific title.
      #
      # TODO: Remove this and update relevant methods when ruby-jss
      # is updated to use JPAPI for Patch Titles..
      #
      JPAPI_PATCH_REPORT_RSRC = 'patch-report'

      SELF_SERVICE_INSTALL_BTN_TEXT = 'Install'

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

      # @return [String] The display name of a version script as a normal
      #   EA in Jamf, which can be used in Smart Groups and Adv Searches.
      #####################
      def self.jamf_normal_ea_name(title)
        "#{ted_ea_key(title)}#{JAMF_NORMAL_EA_NAME_SUFFIX}"
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
      # @return [Pathname] The the local file containing the code of the version script
      #####################
      def self.uninstall_script_file(title)
        title_dir(title) + UNINSTALL_SCRIPT_FILENAME
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
        Xolo::Server.logger.debug "Loading title '#{title}' from file"
        new parse_json(title_data_file(title).read)
      end

      # @param title [String] the title we are looking for
      # @pararm cnx [Windoo::Connection] The Title Editor connection to use
      # @return [Boolean] Does the given title exist in the Title Editor?
      ###############################
      def self.in_ted?(title, cnx:)
        Windoo::SoftwareTitle.all_ids(cnx: cnx).include? title
      end

      # Is a title locked for updates?
      #############################
      def self.locked?(title)
        curr_lock = Xolo::Server.object_locks.dig title, :expires
        curr_lock && curr_lock > Time.now
      end

      # Attributes
      ######################
      ######################

      # For each title there will be a smart group containing all macs
      # that have any version of the title installed. The smart group
      # will be named 'xolo-<title>-installed'
      #
      # It will be used as an exclusion for the initial auto-installation
      # policy for each version since if the title is installed at all,
      # any installation is not 'initial' but an update, and will be
      # handled by the Patch Policy.
      #
      # Since there is one such group per title, it's name is stored here
      #
      # @return [String] the name of the smart group
      attr_reader :jamf_installed_group_name

      # For each title there will be a static group containing macs
      # that should not get any automatic installs or updates, They
      # should be 'frozen' at whatever version was installed when they
      # were added to the group. It will be named 'xolo-<title>-frozen'
      #
      # It will be used as an exclusion for the installation
      # policies and the patch policy for each version.
      #
      # Membership is maintained using `xadm freeze <title> <computer> [<computer> ...]`
      # and `xadm thaw <title> <computer> [<computer> ...]`
      #
      # Use `xadm report <title> frozen` to see a list.
      #
      # If computer groups are used with freeze/thaw, they are expanded and their members
      # added/removed individually in the static group
      #
      # Since there is one such group per title, it's name is stored here
      #
      # @return [String] the name of the smart group
      attr_reader :jamf_frozen_group_name

      # The name of the policy that does initial manual or self-service
      # installs of the currently-released version of this title.
      # It will be named 'xolo-<title>-install'
      attr_reader :jamf_manual_install_released_policy_name

      # If a title is uninstallable, it will have a script in Jamf
      # named 'xolo-<title>-uninstall'
      #
      # @return [String] the name of the script to uninstall the title
      attr_reader :jamf_uninstall_script_name

      # If a title is uninstallable, it will have a policy in Jamf
      # named 'xolo-<title>-uninstall' that will run the script of
      # the same name, using a trigger of the same name.
      #
      # @return [String] the name of the policy to uninstall the title
      attr_reader :jamf_uninstall_policy_name

      # If a title is expirable, it will have a policy in Jamf
      # named 'xolo-<title>-expire' that will run the expiration
      # process daily, at checkin or using a trigger of the same name.
      #
      # @return [String] the name of the policy to uninstall the title
      attr_reader :jamf_expire_policy_name

      # The instance of Xolo::Server::App that instantiated this
      # title object. This is how we access things that are available in routes
      # and helpers, like the single Jamf and TEd
      # connections for this App instance.
      # @return [Xolo::Server::App] our Sinatra server app
      attr_accessor :server_app_instance

      # @return [Integer] The Windoo::SoftwareTitle#softwareTitleId
      attr_accessor :ted_id_number

      # when applying updates, the new data from xadm is stored
      # here so it can be accessed by update-methods
      # and compared to the current instance values
      # both for updating the title, and the versions
      #
      # @return [Hash] The new data to apply as an update
      attr_reader :new_data_for_update

      # Also when applying updates, this will hold the
      # changes being made: the differences between
      # tne current attributes and the new_data_for_update
      # We'll figure this out at the start of the update
      # and can use it later to
      # 1) avoid doing things we don't need to
      # 2) log the changes in the change log at the very end
      #
      # This is a Hash with keys of the attribute names that have changed
      # the values are Hashes with keys of :old and :new
      # e.g. { release_groups: { old: ['foo'], new: ['bar'] } }
      #
      # @return [Hash] The changes being made
      attr_reader :changes_for_update

      # @return [Integer] The Jamf Pro ID for the self-service icon
      #   once it has been uploaded
      attr_accessor :ssvc_icon_id

      # @return [Symbol] The current action being taken on this title
      #   one of :creating, :updating, :deleting
      attr_accessor :current_action

      # @return [String] If current action is :releasing, this is the
      #   version being released
      attr_accessor :releasing_version

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
        @jamf_patch_title_id ||= data_hash[:jamf_patch_title_id]
        @version_order ||= []
        @new_data_for_update = {}
        @changes_for_update = {}
        @jamf_installed_group_name = "#{Xolo::Server::JAMF_OBJECT_NAME_PFX}#{data_hash[:title]}#{JAMF_INSTALLED_GROUP_NAME_SUFFIX}"
        @jamf_frozen_group_name = "#{Xolo::Server::JAMF_OBJECT_NAME_PFX}#{data_hash[:title]}#{JAMF_FROZEN_GROUP_NAME_SUFFIX}"

        @jamf_manual_install_released_policy_name = "#{Xolo::Server::JAMF_OBJECT_NAME_PFX}#{data_hash[:title]}-install"

        @jamf_uninstall_script_name = "#{Xolo::Server::JAMF_OBJECT_NAME_PFX}#{data_hash[:title]}#{JAMF_UNINSTALL_SUFFIX}"
        @jamf_uninstall_policy_name = "#{Xolo::Server::JAMF_OBJECT_NAME_PFX}#{data_hash[:title]}#{JAMF_UNINSTALL_SUFFIX}"
        @jamf_expire_policy_name = "#{Xolo::Server::JAMF_OBJECT_NAME_PFX}#{data_hash[:title]}#{JAMF_EXPIRE_SUFFIX}"
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

      # @return [Boolean] Are we creating this title?
      ###################
      def creating?
        current_action == :creating
      end

      # @return [Boolean] Are we updating this title?
      ###################
      def updating?
        current_action == :updating
      end

      # @return [Boolean] Are we repairing this title?
      ###################
      def repairing?
        current_action == :repairing
      end

      # @return [Boolean] Are we deleting this title?
      ###################
      def deleting?
        current_action == :deleting
      end

      # @return [Boolean] Are we releasing a version this title?
      ###################
      def releasing?
        current_action == :releasing
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
      def jamf_cnx(refresh: false)
        server_app_instance.jamf_cnx refresh: refresh
      end

      # The title dir for this title on the server
      # @return [Pathname]
      #########################
      def title_dir
        @title_dir ||= self.class.title_dir title
      end

      # The title data file for this title on the server
      # @return [Pathname]
      #########################
      def title_data_file
        @title_data_file ||= self.class.title_data_file title
      end

      # @return [Pathname] The the local file containing the self-service icon
      #####################
      def ssvc_icon_file
        @ssvc_icon_file ||= self.class.ssvc_icon_file title
      end

      # @return [Pathname] The the local file containing the code of the version script
      #####################
      def version_script_file
        @version_script_file ||= self.class.version_script_file title
      end

      # The code of the version script, if any,
      # considering the new data of any changes being made
      #
      # Returns nil if there is no version script, or if we are in the
      # process of deleting it.
      #
      # @return [String] The string contents of the version_script, if any
      ####################
      def version_script_contents
        return @version_script_contents if defined? @version_script_contents

        curr_script =
          if changes_for_update&.key? :version_script
            # new, incoming script
            changes_for_update[:version_script][:new]
          else
            # the current attribute value, might be Xolo::ITEM_UPLOADED
            version_script
          end

        @version_script_contents =
          if curr_script.pix_empty?
            # no script, or deleting script
            nil
          elsif curr_script == Xolo::ITEM_UPLOADED
            # use the one we have saved on disk
            version_script_file.read
          else
            # this will be a new one from the changes_for_update
            curr_script
          end
      end

      # @return [Pathname] The the local file containing the code of the uninstall script
      #####################
      def uninstall_script_file
        @uninstall_script_file ||= self.class.uninstall_script_file title
      end

      # The code of the uninstall_script , if any,
      # considering the new data of any changes being made
      #
      # Returns nil if there is no uninstall_script, or if we are in the
      # process of deleting it.
      #
      # @return [String] The string contents of the uninstall_script, if any
      ####################
      def uninstall_script_contents
        return @uninstall_script_contents if defined? @uninstall_script_contents

        # use any new/incoming value if we have any
        # this might still be nil or an empty array if we are removing uninstallability
        curr_script = changes_for_update.dig(:uninstall_script, :new) || changes_for_update.dig(:uninstall_ids, :new)
        curr_script = nil if curr_script.pix_empty?

        # otherwise use the existing value
        curr_script ||= uninstall_script || uninstall_ids

        # now get the actual script
        @uninstall_script_contents =
          if curr_script.pix_empty?
            # removing uninstallability, or it was never added
            nil
          elsif curr_script == Xolo::ITEM_UPLOADED
            # nothing changed, use the one we have saved on disk
            uninstall_script_file.read
          else
            # this will be a new one from the changes_for_update
            generate_uninstall_script curr_script
          end

        # log_debug "Uninstall script contents: #{@uninstall_script_contents}"
        @uninstall_script_contents
      end

      # @param script_or_pkg_ids [String] The new uninstall script, or comma-separated list of pkg IDs
      # @return [String, Array ] The uninstall script, provided or generated from the given pkg ids
      #####################
      def generate_uninstall_script(script_or_pkg_ids)
        # Its already a script, validated by xadm to start with #!
        return script_or_pkg_ids if script_or_pkg_ids.is_a? String

        uninstall_script_template.sub 'PKG_IDS_FROM_XOLO_GO_HERE', script_or_pkg_ids.join(' ')
      end

      # @return [String] The template zsh script for uninstalling via pkgutil
      #####################
      def uninstall_script_template
        # parent 1 = server
        # parent 2 = xolo
        # parent 3 = lib
        # parent 4 = xolo gem
        data_dir = Pathname.new(__FILE__).parent.parent.parent.parent + 'data'
        template_file = data_dir + 'uninstall-pkgs-by-id.zsh'
        template_file.read
      end

      # @return [String] The display name of a version script as a normal
      #   EA in Jamf, which can be used in Smart Groups and Adv Searches.
      #####################
      def jamf_normal_ea_name
        @jamf_normal_ea_name ||= self.class.jamf_normal_ea_name title
      end

      # prepend a new version to the version_order
      #
      # @param version [String] the version to prepend
      #
      # @return [void]
      ########################
      def prepend_version(version)
        lock
        version_order.unshift version
        save_local_data
      ensure
        unlock
      end

      # remove a version from the version_order
      #
      # @param version [String] the version to remove
      #
      # @return [void]
      ########################
      def remove_version(version)
        lock
        version_order.delete version
        save_local_data
      ensure
        unlock
      end

      # instantiate a version if this title
      #
      # @return [Xolo::Server::Version]
      ########################
      def version_object(version)
        log_debug "Instantiating version #{version} from Title instance #{title}"
        server_app_instance.instantiate_version(title: self, version: version)
      end

      # @return [Array<Xolo::Server::Version>] An array of all current version objects
      #   NOTE: This might not be wise if hundreds of versions, but automated cleanup should
      #   help with that.
      ########################
      def version_objects(refresh: false)
        @version_objects = nil if refresh
        return @version_objects if @version_objects

        @version_objects = version_order.map { |v| version_object v }
      end

      # @return [String] The URL path for the patch report for this title
      #############################
      def patch_report_rsrc
        @patch_report_rsrc ||= "#{JPAPI_PATCH_TITLE_RSRC}/#{jamf_patch_title_id}/#{JPAPI_PATCH_REPORT_RSRC}"
      end

      # Save a new title, adding to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      #
      # @return [void]
      #########################
      def create
        lock

        @current_action = :creating

        self.creation_date = Time.now
        self.created_by = admin
        log_debug "creation_date: #{creation_date}, created_by: #{created_by}"

        # this will create the title as needed in the Title Editor
        create_title_in_ted
        create_title_in_jamf

        # save to file last, because saving to TitleEd and Jamf will
        # add some data
        progress 'Saving title data to Xolo server'
        save_local_data

        log_change msg: 'Title Created'

        # ssvc icon is uploaded in a separate process, and the
        # title data file will be updated as needed then.
      ensure
        unlock
      end

      # Update this title, updating to the
      # local filesystem, Jamf Pro, and the Title Editor,
      # and applying any changes to existing versions as needed.
      #
      # @param new_data [Hash] The new data sent from xadm
      # @return [void]
      #########################
      def update(new_data)
        lock

        @current_action = :updating
        @new_data_for_update = new_data
        @changes_for_update = note_changes_for_update_and_log

        if @changes_for_update.pix_empty?
          progress 'No changes to make', log: :info
          return
        end

        log_info "Updating title '#{title}' for admin '#{admin}'"
        log_debug "Updating title with these changes: #{changes_for_update}"

        # changelog - log the changes now, and
        # if there is an error, we'll log that too
        # saying the above changes were not completed and to
        # look at the server log for details.
        log_update_changes

        # Do ted before doing things in Jamf
        update_title_in_ted
        update_title_in_jamf
        update_local_instance_values
        save_local_data

        # if we already have a version script, and it hasn't changed, the new data should
        # contain Xolo::ITEM_UPLOADED. If its nil, we shouldn't
        # have one at all and should remove the old one if its there
        delete_version_script_file unless new_data_for_update[:version_script]

        # Do This at the end - after all the versions/patches have been updated.
        # Jamf won't see the need for re-acceptance until after the title
        # (and at least one patch) have been re-enabled.
        accept_xolo_patch_ea_in_jamf if need_to_accept_xolo_ea_in_jamf?

        # any new self svc icon will be uploaded in a separate process
        # and the local data will be updated again then
        #
      rescue => e
        log_change msg: "ERROR: The update failed and the changes didn't all go through!\n#{e.class}: #{e.message}\nSee server log for details."

        # re-raise for proper error handling in the server app
        raise
      ensure
        unlock
      end # update

      # Update our instance attributes with any new data before
      # saving the changes back out to the file system
      # @return [void]
      ###########################
      def update_local_instance_values
        # update instance data with new data before writing out to the filesystem.
        # Do this last so that the instance values can be compared to
        # new_data_for_update in the steps above.
        # Also, those steps might have updated some server-specific attributes
        # which will be saved to the file system as well.
        ATTRIBUTES.each do |attr, deets|
          # make sure these are updated elsewhere if needed,
          # e.g. modification data.
          next if deets[:read_only]
          next unless deets[:cli]

          new_val = new_data_for_update[attr]
          old_val = send(attr)
          next if new_val == old_val

          log_debug "Updating Xolo Title attribute '#{attr}': '#{old_val}' -> '#{new_val}'"
          send "#{attr}=", new_val
        end

        # update any other server-specific attributes here...
      end

      # Save our current data out to our JSON data file
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_local_data
        # create the dirs for the title
        title_dir.mkpath
        vdir = title_dir + Xolo::Server::Version::VERSIONS_DIRNAME
        vdir.mkpath

        save_version_script
        save_uninstall_script

        self.modification_date = Time.now
        self.modified_by = admin
        log_debug "Title '#{title}' noting modification by #{modified_by}"

        # do we have a stored self service icon?
        self.self_service_icon = ssvc_icon_file ? Xolo::ITEM_UPLOADED : nil

        log_debug "Saving local title data to: #{title_data_file}"
        title_data_file.pix_atomic_write to_json
      end

      # Save our current version script out to our local file,
      # but only if we aren't using app_name and app_bundle_id
      # and only if it's changed
      #
      # This won't delete the script if it's being removed, that
      # happens elsewhere.
      #
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_version_script
        return if app_name || app_bundle_id
        return if version_script_contents.nil?

        log_debug "Saving version_script to: #{version_script_file}"
        version_script_file.pix_atomic_write version_script_contents

        # the json file only stores 'uploaded' in the version_script attr.
        self.version_script = Xolo::ITEM_UPLOADED
      end

      # Save our current uninstall script out to our local file.
      #
      # This won't delete the script if it's being removed, that
      # happens elsewhere.
      #
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_uninstall_script
        return if uninstall_script == Xolo::ITEM_UPLOADED || uninstall_ids == Xolo::ITEM_UPLOADED
        return if uninstall_script_contents.nil?

        log_debug "Saving uninstall script to: #{uninstall_script_file}"
        uninstall_script_file.pix_atomic_write uninstall_script_contents

        # the json file only stores 'uploaded' in uninstall_script
        # The actual script is saved in its own file.
        self.uninstall_script &&= Xolo::ITEM_UPLOADED
      end

      # are we uninstallable?
      #
      # @return [Boolean]
      ##########################
      def uninstallable?
        uninstall_script || !uninstall_ids.pix_empty?
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
        lock
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
      ensure
        unlock
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
        lock
        @current_action = :deleting

        progress "Deleting all versions of #{title}...", log: :debug
        # Delete them in reverse order (oldest first) so the jamf server doesn't
        # see each older version as being 'released' again as newer
        # ones are deleted.
        version_objects.reverse.each do |vers|
          vers.delete update_title: false
        end

        delete_title_from_ted

        delete_title_from_jamf

        delete_changelog

        progress "Deleting Xolo server data for title '#{title}'", log: :info
        title_dir.rmtree
      ensure
        unlock
      end

      # Release a version of this title
      #
      # @param version_to_release [String] the version to release
      #
      # @return [void]
      ##########################
      def release(version_to_release)
        lock
        @current_action = :releasing
        @releasing_version = version_to_release

        validate_release(version_to_release)

        progress "Releasing version #{version_to_release} of title '#{title}'", log: :info

        update_versions_for_release version_to_release

        # update the title
        self.released_version = version_to_release
        save_local_data
      ensure
        unlock
      end

      # are we OK releasing a given version?
      # @return [void]
      ######################################
      def validate_release(version_to_release)
        if released_version == version_to_release
          raise Xolo::InvalidDataError,
                "Version '#{version_to_release}' of title '#{title}' is already released"
        end

        return if versions.include? version_to_release

        raise Xolo::NoSuchItemError,
              "No version '#{version_to_release}' for title '#{title}'"
      end

      # Update all versions when releasing one
      # @param version_to_release [String] the version to release
      # @return [void]
      ##############################
      def update_versions_for_release(version_to_release)
        # get the Version objects and figure out our starting point, but process
        # them in reverse order so that we don't have two released versions at once
        all_versions = version_objects.reverse
        vobj_to_release = all_versions.find { |v| v.version == version_to_release }
        vobj_current_release = all_versions.find { |v| v.version == released_version }

        rollback = vobj_current_release && vobj_to_release < vobj_current_release

        progress "Rolling back from version #{released_version}", log: :info if rollback

        all_versions.each do |vobj|
          # This is the one we are releasing
          if vobj == vobj_to_release
            release_version(vobj, rollback: rollback)

          # This one is older than the one we're releasing
          # so its either deprecated or skipped
          elsif vobj < vobj_to_release
            deprecate_or_skip_version(vobj)

          # this one is newer than the one we're releasing
          # revert to pilot if appropriate
          else
            reset_version_to_pilot(vobj)

          end # if vobj == vobj_to_release
        end # all_versions.each
      end

      # release a specific version
      # @param vobj [Xolo::Server::Version] the version object to be released
      # @return [void]
      #######################################
      def release_version(vobj, rollback:)
        vobj.release rollback: rollback

        # update the jamf_manual_install_released_policy to install this version
        msg = "Jamf: Setting policy #{jamf_manual_install_released_policy_name} to install the package for version '#{vobj.version}'"
        progress msg, log: :info

        pol = jamf_manual_install_released_policy
        pol.package_ids.each { |pid| pol.remove_package pid }
        pol.add_package vobj.jamf_pkg_id
        pol.save
      end

      # Deprecate or skip a version
      # @param vobj [Xolo::Server::Version] the version object to be deprecated or skipped
      # @return [void]
      #######################################
      def deprecate_or_skip_version(vobj)
        # don't do anything if the status is already deprecated or skipped

        # but if its released, we need to deprecate it
        vobj.deprecate if vobj.status == Xolo::Server::Version::STATUS_RELEASED

        # and skip it if its in pilot
        vobj.skip if vobj.status == Xolo::Server::Version::STATUS_PILOT
      end

      # reset a version to pilot status, this happens when rolling back
      # (releasing a version older than the current release)
      # @param vobj [Xolo::Server::Version] the version object to be deprecated or skipped
      # @return [void]
      #############################
      def reset_version_to_pilot(vobj)
        # do nothing if its in pilot
        return if vobj.status == Xolo::Server::Version::STATUS_PILOT

        # this should be redundant with the above?
        return unless rollback

        # if we're here, we're rolling back to something older than this
        # version, and this version is currently released, deprecated or skipped.
        # We need to reset it to pilot.
        vobj.reset_to_pilot
      end

      # Repair this title, and optionally all of its versions.
      #
      # Look at the Title Editor title object, and ensure it's correct based on the local data file.
      #   - display name
      #   - publisher
      #   - EA or app-data
      #     - ea name 'xolo-<title>'
      #   - requirement criteria
      #   - stub version if needed
      #   - enabled
      #
      # Then look at the various Jamf objects pertaining to this title, and ensure they are correct
      #   - Accept Patch EA
      #   - Normal EA 'xolo-<title>-installed-version'
      #   - title-installed smart group 'xolo-<title>-installed'
      #   - frozen static group 'xolo-<title>-frozen'
      #   - manual/SSvc install-current-release policy 'xolo-<title>-install'
      #     - trigger 'xolo-<title>-install'
      #     - ssvc icon
      #     - ssvc category
      #     - description
      #   - if uninstallable
      #     - uninstall script 'xolo-<title>-uninstall'
      #     - uninstall policy 'xolo-<title>-uninstall'
      #     - if expirable
      #       - expire policy 'xolo-<title>-expire'
      #         - trigger  'xolo-<title>-expire'
      #
      # @param repair_versions [Boolean] run the repair method on all versions?
      # @return [void]
      ##################################
      def repair(repair_versions: false)
        lock
        @current_action = :repairing
        chg_log_msg = repair_versions ? 'Repairing title and all versions' : 'Repairing title only'
        log_change msg: chg_log_msg

        progress "Starting repair of title '#{title}'"
        repair_ted_title
        repair_jamf_title_objects
        return unless repair_versions

        version_objects.each do |vobj|
          progress '#########'
          vobj.repair
        end
      ensure
        unlock
      end

      # Is this title locked for updates?
      #############################
      def locked?
        self.class.locked?(title)
      end

      # Lock this title for updates
      #############################
      def lock
        raise Xolo::ServerError, 'Server is shutting down' if Xolo::Server.shutting_down?

        while locked?
          log_debug "Waiting for update lock on title '#{title}'..." if (Time.now.to_i % 5).zero?
          sleep 0.33
        end
        Xolo::Server.object_locks[title] ||= { versions: {} }

        exp = Time.now + Xolo::Server::ObjectLocks::OBJECT_LOCK_LIMIT
        Xolo::Server.object_locks[title][:expires] = exp
        log_debug "Locked title '#{title}' for updates until #{exp}"
      end

      # Unlock this v for updates
      #############################
      def unlock
        curr_lock = Xolo::Server.object_locks.dig title, :expires
        return unless curr_lock

        Xolo::Server.object_locks[title].delete :expires
        log_debug "Unlocked title '#{title}' for updates"
      end

      # Add more server-specific data to our hash
      ###########################
      def to_h
        hash = super
        hash[:ted_id_number] = ted_id_number
        hash[:ssvc_icon_id] = ssvc_icon_id
        hash
      end

    end # class Title

  end # module Admin

end # module Xolo
