# Copyright 2025 Pixar
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

    # Xolo Version/Patch as used on the Xolo Server
    #
    # The code in this file mostly deals with the data on the Xolo server itself, and
    # general methods for manipulating the version.
    #
    # Code for interacting with the Title Editor and Jamf Pro are in the helpers and mixins.
    #
    # NOTE be sure to only instantiate these using the
    # server's 'instantiate_version' method, or else
    # they might not have all the correct innards
    ###
    class Version < Xolo::Core::BaseClasses::Version

      # Mixins
      #############################
      #############################
      include Comparable

      include Xolo::Server::Helpers::JamfPro
      include Xolo::Server::Helpers::TitleEditor
      include Xolo::Server::Helpers::Log
      include Xolo::Server::Helpers::Notification

      include Xolo::Server::Mixins::Changelog
      include Xolo::Server::Mixins::VersionJamfAccess
      include Xolo::Server::Mixins::VersionTedAccess

      # Constants
      ######################
      ######################

      # On the server, xolo versions are represented by JSON files
      # in the 'versions' directory of the title directory
      #
      # So a title 'foobar' would have a directory
      #    (Xolo::Server::DATA_DIR)/titles/foobar/
      #
      # In there will be a 'versions' dir containing json
      # files for each version of the title.
      #
      VERSIONS_DIRNAME = 'versions'

      JAMF_PKG_NOTES_VERS_PH = 'XOLO-VERSION-HERE'
      JAMF_PKG_NOTES_TITLE_PH = 'XOLO-TITLE-HERE'

      # The 'Notes' of a jamf pkg are the Xolo Title Description, with this prepended
      JAMF_PKG_NOTES_PREFIX = <<~ENDNOTES
        This package is maintained by 'xolo', to install version '#{JAMF_PKG_NOTES_VERS_PH}' of title '#{JAMF_PKG_NOTES_TITLE_PH}'. The description in Xolo is:


      ENDNOTES

      MAX_PKG_DELETION_THREADS = 10

      # STUB PATCH
      #
      # We create a fake 'stub' patch with all ted titles
      # so that we can activate the title before any real version is added
      # and also accept any EA/version_script, either manually or automatically
      #
      # This version should never be available to any mac, and needs no patch
      # policies or packages.
      #
      # It should also never be deleted until the title itself is deleted.

      STUB_PATCH_VERSION = '0.0.0x0'

      # machines that can install this version
      STUB_PATCH_CAPABILITY_CRITERION_NAME = 'Operating System Version'
      STUB_PATCH_CAPABILITY_CRITERION_OPERATOR = 'less than or equal'
      STUB_PATCH_CAPABILITY_CRITERION_VALUE = '10.0'

      # machines that have this version installed
      STUB_PATCH_COMPONENT_NAME = 'Xolo Stub'
      STUB_PATCH_COMPONENT_CRITERION_NAME = 'Application Title'
      STUB_PATCH_COMPONENT_CRITERION_OPERATOR = 'is'
      STUB_PATCH_COMPONENT_CRITERION_VALUE = 'XoloStub-DoesNotExist.app'

      # Class Methods
      ######################
      ######################

      # @pararm title [String] the title for the version
      # @return [Pathname]  The directory containing subdirectories for each version of a title.
      #   They contain JSON and other files for the versions.
      ######################
      def self.version_dir(title)
        Xolo::Server::Title.title_dir(title) + VERSIONS_DIRNAME
      end

      # @pararm title [String] the title for the versions
      # @return [Array<Pathname>] All version directories for a title
      ######################
      def self.version_dirs(title)
        vdir = version_dir(title)
        vdir.directory? ? vdir.children : []
      end

      # @pararm title [String] the title for the version
      # @return [Array<String>] A list of all known versions for a title,
      #   just the basenames of all the version files with the extension removed
      ######################
      def self.all_versions(title)
        version_dirs(title).map { |c| c.basename.to_s }
      end

      # The the local directory containing various files
      # specific to the given version of a title
      #
      # @pararm title [String] the title for the version
      #
      # @pararm version [String] the version we care about
      #
      # @return [Pathname]
      #####################
      def self.data_dir(title, version)
        version_dir(title) + version
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
      def self.data_file(title, version)
        data_dir(title, version) + "#{version}.json"
      end

      # The the local xml plist file containing the
      # .pkg manifest for the given version of a title
      #
      # @pararm title [String] the title for the version
      #
      # @pararm version [String] the version we care about
      #
      # @return [Pathname]
      #####################
      def self.manifest_file(title, version)
        data_dir(title, version) + "#{version}.manifest.plist"
      end

      # Instantiate from the local JSON file containing the current values
      # for the given version of a title
      #
      # NOTE: All instantiation should happen using the #instantiate_version method
      # in the server app instance. Please don't call this method directly
      #
      # @pararm title [String] the title for the version
      #
      # @pararm version [String] the version we care about
      #
      # @return [Xolo::Server::Title] load an existing title
      #   from the on-disk JSON file
      ######################
      def self.load(title, version)
        new parse_json(data_file(title, version).read)
      end

      # @param patch_id [String] the id number of the patch we are looking for
      # @pararm cnx [Windoo::Connection] The Title Editor connection to use
      # @return [Boolean] Does the given patch exist in the Title Editor?
      ###############################
      def self.in_ted?(patch_id, cnx:)
        Windoo::Patch.all_ids(cnx: cnx).include? patch_id
      end

      # Is a version locked for updates?
      #############################
      def self.locked?(title, version)
        curr_lock = Xolo::Server.object_locks.dig title, :versions, version
        curr_lock && curr_lock > Time.now
      end

      # The package-deletion thread pool
      #
      # the auto_terminate is false to prevents the threads from being daemonized,
      # and running after the main thread exits. This is important because launchd
      # jobs should never do that.
      #
      # See https://ruby-concurrency.github.io/concurrent-ruby/master/file.thread_pools.html
      # @return [Queue] The package-deletion thread pool
      ###############################
      def self.pkg_deletion_pool
        @pkg_deletion_pool ||= Concurrent::ThreadPoolExecutor.new(
          name: 'package-deletion',
          min_threads: 1, # start with 1 thread
          max_threads: MAX_PKG_DELETION_THREADS, # create at most 10 threads
          max_queue: 0, # no limit
          auto_terminate: false, # see method comments above
          idletime: 60 # seconds thread can remain idle before it is reclaimed, default is 60
          # fallback_policy: :abort # the default is :abort, which will raise a
          #   Concurrent::RejectedExecutionError exception and discard the task
        )
      end

      # info about the current pkg deletion pool state, for
      # the /state route
      # @return [Hash]
      ###############################
      def self.pkg_deletion_pool_info
        {
          threads: pkg_deletion_pool.length,
          queued_tasks: pkg_deletion_pool.queue_length
        }
      end

      # Attributes
      ######################
      ######################

      # The instance of Xolo::Server::App that instantiated this
      # title object. This is how we access things that are available in routes
      # and helpers, like the single Jamf and TEd
      # connections for this App instance.
      attr_accessor :server_app_instance

      # The sinatra session that instantiates this version
      # attr_writer :session

      # The Xolo::Server::Title that contains, and usually instantiated
      #   this version object
      attr_writer :title_object

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

      # Jamf Patch Policy is named this
      attr_reader :jamf_patch_policy_name

      # The Jamf Package object has this jamf id
      attr_reader :jamf_pkg_id

      # when applying updates, the new data is stored
      # here so it can be accessed by update-methods
      # and compared to the current instanace values
      # both for updating the title, and the versions
      attr_reader :new_data_for_update

      # Also when applying updates, this will hold the
      # changes being made: the differences between
      # tne current attributs and the new_data_for_update
      # We'll figure this out at the start of the update
      # and can use it later to
      # 1) avoid doing things we don't need to
      # 2) log the changes in the change log at the very end
      #
      # This is a Hash with keys of the attribute names that have changed
      # the values are Hashes with keys of :old and :new
      # e.g. { pilot_groups: { old: ['foo'], new: ['bar'] } }
      # @return [Hash]
      attr_reader :changes_for_update

      # @return [Symbol] The current action being taken on this title
      #   one of :creating, :updating, :deleting
      attr_accessor :current_action

      # Constructor
      ######################
      ######################

      # NOTE: be sure to only instantiate these using the
      # servers 'instantiate_version' method, or else
      # they might not have all the correct innards
      def initialize(data_hash)
        super

        # These attrs aren't defined in the ATTRIBUTES
        # and/or are not stored in the on-disk json file

        @ted_id_number ||= data_hash[:ted_id_number]
        @jamf_pkg_id ||= data_hash[:jamf_pkg_id]

        # and these can be generated now
        @jamf_obj_name_pfx = "#{Xolo::Server::JAMF_OBJECT_NAME_PFX}#{title}-#{version}"

        @jamf_pkg_name ||= @jamf_obj_name_pfx

        @jamf_auto_install_policy_name = "#{jamf_obj_name_pfx}#{JAMF_POLICY_NAME_AUTO_INSTALL_SFX}"
        @jamf_manual_install_policy_name = "#{jamf_obj_name_pfx}#{JAMF_POLICY_NAME_MANUAL_INSTALL_SFX}"

        @jamf_patch_policy_name = @jamf_obj_name_pfx

        # we set @jamf_pkg_file when a pkg is uploaded
        # since we don't know until then if its a .pkg or .zip
        # It will be stored in the local data and reloaded as needed
      end

      # Instance Methods
      ######################
      ######################

      # version comparison
      # @see Comparable
      #########################
      def <=>(other)
        raise Xolo::InvalidDataError, 'Cannot compare with other classes' unless other.is_a? Xolo::Server::Version
        raise Xolo::InvalidDataError, 'Cannot compare versions of different titles' unless other.title == title

        order_index <=> other.order_index
      end

      # @return [Integer] The index of this version in the title's reversed version_order array.
      #   We reverse it because the version_order array holds the newest versions first,
      #   so the index of the newest version is 0, the next newest is 1, etc - we need the opposite of that.
      ######################
      def order_index
        title_object.version_order.reverse.index version
      end

      # @return [Boolean] Are we creating this version?
      ###################
      def creating?
        current_action == :creating
      end

      # @return [Boolean] Are we updating this version?
      ###################
      def updating?
        current_action == :updating
      end

      # @return [Boolean] Are we repairing this version?
      ###################
      def repairing?
        current_action == :repairing
      end

      # @return [Boolean] Are we deleting this version?
      ###################
      def deleting?
        current_action == :deleting
      end

      # @return [Boolean] Are we releasing this version?
      ###################
      def releasing?
        current_action == :releasing
      end

      # The scope target groups to use in policies and patch policies during pilot
      # This is defined in each version, and inherited when new versions are created.
      #
      # @return [Array<String>] the pilot groups to use
      ######################
      def pilot_groups_to_use
        return @pilot_groups_to_use if @pilot_groups_to_use

        @pilot_groups_to_use = changes_for_update&.key?(:pilot_groups) ? changes_for_update[:pilot_groups][:new] : pilot_groups
      end

      # The scope excluded groups to use in policies and patch policies for all versions of
      # this title.
      #
      # Excluded groups are defined in the title, applying to all versions, and may be augmented by:
      # - Xolo::Server.config.forced_exclusion, a group excluded from ALL of xolo, defined
      #   in the server config.
      # - The title's jamf_frozen_group_name, if it exists, containing computers that have been
      #   'frozen' to a single version.
      #
      # For initial install policies, the smart group of macs with any version installed
      # (jamf_installed_group_name) "xolo-<title>-installed" is also excluded, because
      # otherwise the initial-install policies would stomp on the patch policies.
      #
      # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
      #   if nil, we'll instantiate it now
      #
      # @return [Array<String>] the excluded groups to use
      ######################
      def excluded_groups_to_use(ttl_obj: nil)
        return @excluded_groups_to_use if @excluded_groups_to_use

        ttl_obj ||= title_object
        # get the excluded groups from the title
        # Use .dup so we don't modify the original
        @excluded_groups_to_use = ttl_obj.changes_for_update&.key?(:excluded_groups) ? ttl_obj.changes_for_update[:excluded_groups][:new].dup : ttl_obj.excluded_groups.dup

        # always exclude the frozen static group
        # calling ttl_obj.jamf_frozen_group will create the group if needed
        @excluded_groups_to_use << ttl_obj.jamf_frozen_group.name
        log_debug "Appended '#{ttl_obj.jamf_frozen_group_name}' to @excluded_groups_to_use"

        # always exclude Xolo::Server.config.forced_exclusion if defined
        @excluded_groups_to_use << valid_forced_exclusion_group_name if valid_forced_exclusion_group_name

        @excluded_groups_to_use.uniq!
        log_debug "Excluded groups to use: #{@excluded_groups_to_use.join ', '}"

        @excluded_groups_to_use
      end

      # The scope target groups to use in policies and patch policies when the version is released
      # This is defined in the title and applies to all versions.
      #
      # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
      #   if nil, we'll instantiate it now
      #
      # @return [Array<String>] the target groups to use
      ######################
      def release_groups_to_use(ttl_obj: nil)
        return @release_groups_to_use if @release_groups_to_use

        ttl_obj ||= title_object
        @release_groups_to_use = ttl_obj.changes_for_update&.key?(:release_groups) ? ttl_obj.changes_for_update[:release_groups][:new] : ttl_obj.release_groups
      end

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

      # This might have been set already if we were instantiated via our title
      # @return [Xolo::Server::Title] the title for this version
      ################
      def title_object(refresh: false)
        @title_object = nil if refresh
        @title_object ||= server_app_instance.instantiate_title title
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

      # The data directory for this version
      # @return [Pathname]
      #########################
      def data_dir
        self.class.data_dir title, version
      end

      # The JSON data file for this version
      # @return [Pathname]
      #########################
      def data_file
        self.class.data_file title, version
      end

      # The manifest plist file for this version
      # @return [Pathname]
      #########################
      def manifest_file
        self.class.manifest_file title, version
      end

      # TODO: maybe pass in an appropriate Windoo::SoftwareTitle, so
      # we don't have to use refresh all the time to re-fetch, if we just
      # re-fetched from elsewhere?
      #
      # @return [Windoo::Patch] The Windoo::Patch object that represents
      #   this version in the title editor
      #############################
      def ted_patch(refresh: false)
        @ted_patch = nil if refresh
        @ted_patch ||= ted_title(refresh: refresh).patches.patch(version)
      end

      # @return [Windoo::SoftwareTitle] The Windoo::SoftwareTitle object that represents
      #   this version's title in the title editor
      #############################
      def ted_title(refresh: false)
        @ted_title = nil if refresh
        @ted_title ||= Windoo::SoftwareTitle.fetch id: title, cnx: ted_cnx
      end

      # Save a new version, adding to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      # This should be running in the context of #with_streaming
      #
      # @return [void]
      #########################
      def create
        lock
        @current_action = :creating

        self.creation_date = Time.now
        self.created_by = admin
        self.status = STATUS_PENDING
        log_debug "creation_date: #{creation_date}, created_by: #{created_by}"

        # save to file here so that we have something to delete if
        # the next couple steps fail
        progress 'Saving version data to Xolo server'
        save_local_data

        create_patch_in_ted
        enable_ted_patch
        title_object.enable_ted_title

        create_in_jamf

        self.status = STATUS_PILOT

        # save to file again now, because saving to TitleEd and Jamf will
        # add some data
        save_local_data

        # prepend our version to the version_order array of the title
        progress "Updating title version_order, prepending '#{version}'", log: :info
        title_object.prepend_version(version)

        log_change msg: 'Version Created'

        progress "Version '#{version}' of Title '#{title}' has been created in Xolo.", log: :info
      ensure
        unlock
      end

      # Update a this version, updating to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
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

        log_info "Updating version '#{version}' of title '#{title}' for admin '#{admin}'"

        # changelog - log the changes now, and
        # if there is an error, we'll log that too
        # saying the above changes were not completed and to
        # look at the server log for details.
        log_update_changes

        # update ted before jamf
        update_patch_in_ted
        enable_ted_patch
        update_version_in_jamf
        update_local_instance_values
        save_local_data

        # new pkg uploads happen in a separate process
      rescue StandardError => e
        log_change msg: "ERROR: The update failed and the changes didn't all go through!\n#{e.class}: #{e.message}\nSee server log for details."

        # re-raise for proper error handling in the server app
        raise
      ensure
        unlock
      end

      # Repair this version.
      # Look at the Title Editor patch object, and ensure it's correct based on the local data file.
      #   - version order
      #   - min os
      #   - max os
      #   - standalone
      #   - reboot
      #   - release date
      #   - killapps
      #   - component criteria
      #     - component name '<title>'
      #   - capability criteria
      #   - enabled
      #
      # Then look at the various Jamf objects pertaining to this version, and ensure they are correct
      #   - package object 'xolo-<title>-<version>'
      #     - filename 'xolo-<title>-<version>.pkg'
      #     - description
      #     - os limitations
      #   - auto install policy 'xolo-<title>-<version>-auto-install'
      #   - manual install policy  'xolo-<title>-<version>-manual-install'
      #   - patch policy 'xolo-<title>-<version>'
      #
      ##################################
      def repair
        lock
        @current_action = :repairing
        repair_ted_patch
        repair_jamf_version_objects
      ensure
        unlock
      end

      # Release this version, possibly rolling back from a previously newer version
      #
      # @param rollback [Boolean] If true, this version is being released as a rollback
      #
      # @return [void]
      #########################
      def release(rollback:)
        lock
        @current_action = :releasing
        # set scope targets of auto-install policy to release-groups
        msg = "Jamf: Version '#{version}': Setting scope targets of auto-install policy to release_groups: #{release_groups_to_use.join(', ')}"
        progress msg, log: :info
        pol = jamf_auto_install_policy
        set_policy_release_groups pol
        pol.save

        # set scope targets of patch policy to all (in patch pols, 'all' means 'all eligible')
        msg = "Jamf: Version '#{version}': Setting scope targets of patch policy to all eligible computers"
        progress msg, log: :info
        ppol = jamf_patch_policy
        ppol.scope.set_all_targets

        # if rollback, make sure the patch policy is set to 'allow downgrade'
        if rollback
          msg = "Jamf: Version '#{version}': Setting patch policy to allow downgrade"
          progress msg, log: :info
          ppol.allow_downgrade = true
        else
          ppol.allow_downgrade = false
        end
        ppol.save

        # change status to 'released'
        self.status = STATUS_RELEASED
        self.release_date = Time.now
        self.released_by = admin
        chg_msg = rollback ? 'Version Released - Rolled Back' : 'Version Released'
        log_change msg: chg_msg

        save_local_data
      ensure
        unlock
      end

      # deprecate this version
      #
      # @return [void]
      #########################
      def deprecate
        lock
        progress "Deprecating older released version '#{version}'"
        disable_policies_for_deprecation_or_skipping :deprecated
        self.status = STATUS_DEPRECATED
        self.deprecation_date = Time.now
        self.deprecated_by = admin
        log_change msg: 'Version Deprecated'

        save_local_data
      ensure
        unlock
      end

      # skip this version
      #
      # @return [void]
      #########################
      def skip
        lock
        progress "Skipping unreleased version '#{version}'"
        disable_policies_for_deprecation_or_skipping :skipped
        self.status = STATUS_SKIPPED
        self.skipped_date = Time.now
        self.skipped_by = admin
        log_change msg: 'Version Skipped'
        save_local_data
      ensure
        unlock
      end

      # Reset this version to 'pilot' status, since we are rolling back
      # to a previous version
      #
      # @return [void]
      #########################
      def reset_to_pilot
        return if status == STATUS_PILOT

        lock
        progress "Resetting version '#{version}' to pilot status due to rollback of an older version"
        reset_policies_to_pilot
        self.status = STATUS_PILOT
        self.skipped_date = nil
        self.skipped_by = nil
        self.deprecation_date = nil
        self.deprecated_by = nil
        log_change msg: 'Version Reset to Pilot'
        save_local_data
      ensure
        unlock
      end

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

          log_debug "Updating Xolo Version attribute '#{attr}': '#{old_val}' -> '#{new_val}'"
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
        data_dir.mkpath

        self.modification_date = Time.now
        self.modified_by = admin
        log_debug "Version '#{version}' of Title '#{title}' noting modification by #{modified_by}"

        file = data_file
        log_debug "Saving local version data to: #{file}"
        file.pix_atomic_write to_json
      end

      # Delete the version
      #
      # @param update_title [Boolean] Update the title for this version to
      #   know the version is gone. Set this to false when the title itself
      #   is being deleted and calling this method.
      #
      # @return [void]
      ##########################
      def delete(update_title: true)
        lock
        @current_action = :deleting

        delete_patch_from_ted
        delete_version_from_jamf

        # remove from the title's list of versions
        progress 'Deleting version from title data on the Xolo server', log: :debug
        title_object.remove_version(version) if update_title

        # delete the local data
        progress 'Deleting version data from the Xolo server', log: :info
        data_dir.rmtree
        log_change msg: 'Version Deleted'

        progress "Version '#{version}' of Title '#{title}' has been deleted from Xolo.", log: :info
      ensure
        unlock
      end

      # Is this version locked for updates?
      #############################
      def locked?
        self.class.locked?(title, version)
      end

      # Lock this version for updates
      #############################
      def lock
        raise Xolo::ServerError, 'Server is shutting down' if Xolo::Server.shutting_down?

        while locked?
          log_debug "Waiting for update lock on Version '#{version}' of title '#{title}'..."
          sleep 0.33
        end
        Xolo::Server.object_locks[title] ||= { versions: {} }

        exp = Time.now + Xolo::Server::ObjectLocks::OBJECT_LOCK_LIMIT
        Xolo::Server.object_locks[title][:versions][version] = exp
        log_debug "Locked version '#{version}' of title '#{title}' for updates until #{exp}"
      end

      # Unlock this version for updates
      #############################
      def unlock
        curr_lock = Xolo::Server.object_locks.dig title, :versions, version
        return unless curr_lock

        Xolo::Server.object_locks[title][:versions].delete version
        log_debug "Unlocked version '#{version}' of title '#{title}' for updates"
      end

      # Add more data to our hash
      ###########################
      def to_h
        hash = super

        # These attrs aren't defined in the ATTRIBUTES
        # but we want them in the hash and/or JSON
        hash[:jamf_pkg_id] = jamf_pkg_id
        hash[:ted_id_number] = ted_id_number
        hash[:pilot_groups_to_use] = pilot_groups_to_use
        hash[:release_groups_to_use] = release_groups_to_use

        hash.sort.to_h
      end

    end # class Version

  end # module Server

end # module Xolo
