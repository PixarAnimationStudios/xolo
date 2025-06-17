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

  module Core

    module BaseClasses

      # The base class for dealing with Versions/Patches in the
      # Xolo Server, Admin, and Client modules.
      #
      # This class holds the common aspects of Xolo Versinos as used
      # on the Xolo server, in the Xolo Admin CLI app 'xadm', and the
      # client app 'xolo' - most importately it defines which data they
      # exchange.
      #
      ############################
      class Version < Xolo::Core::BaseClasses::ServerObject

        # Mixins
        #############################
        #############################

        # Constants
        #############################
        #############################

        # The title editor requires a value for min os, so use this
        # as the default
        DEFAULT_MIN_OS = '10.9'

        # when this is provided as a killapp, the killapp will
        # be defined by the app_name and app_bundle_id used in the
        # title.
        USE_TITLE_FOR_KILLAPP = 'use-title'

        # Has been created in Xolo, but not yet made available
        # for installation
        STATUS_PENDING = 'pending'

        # Has been released from the Title Editor, but is only
        # available for piloting in Xolo. Will be auto-installed
        # on non-excluded members of the pilot groups
        STATUS_PILOT = 'pilot'

        # Has been fully released in Xolo, this is the currently
        # 'live' version. Will be auto-installed
        # on non-excluded members of the target groups
        STATUS_RELEASED = 'released'

        # Was pending or pilot, but was never released in Xolo,
        # and now a newer version has been released
        STATUS_SKIPPED = 'skipped'

        # Was released in Xolo, but now a newer version has been
        # released
        STATUS_DEPRECATED = 'deprecated'

        # Attributes
        ######################
        ######################

        # Attributes of Versions
        # See the definition for {Xolo::Core::BaseClasses::Title::ATTRIBUTES}
        ATTRIBUTES = {

          # @!attribute title
          #   @return [String] The title to which this version belongs
          title: {
            label: 'Title',
            read_only: true,
            immutable: true,
            cli: false,
            type: :string,
            validate: true,
            invalid_msg: 'Not a valid version! Cannot already exist in this title.',
            desc: <<~ENDDESC
              A unique version string identifying this version in this title, e.g. '12.34.5'.
            ENDDESC
          },

          # @!attribute version
          #   @return [String] The version-string for this version.
          version: {
            label: 'Version',
            required: true,
            immutable: true,
            do_not_inherit: true,
            cli: false,
            type: :string,
            validate: true,
            invalid_msg: 'Not a valid version! Cannot already exist in this title.',
            ted_attribute: :version,
            desc: <<~ENDDESC
              A unique version string identifying this version in this title, e.g. '12.34.5'.
            ENDDESC
          },

          # @!attribute publish_date
          #   @return [Time] When the publisher released this version. Defaults to today.
          publish_date: {
            label: 'Publish Date',
            type: :time,
            default: -> { Time.now.to_s },
            do_not_inherit: true,
            cli: :d,
            validate: true,
            changelog: true,
            ted_attribute: :releaseDate,
            invalid_msg: 'Not a valid date!',
            desc: <<~ENDDESC
              The date this version was released by the publisher.
              Default is today.
            ENDDESC
          },

          # @!attribute min_os = required to create the Title Editor Patch
          #   @return [String] The minimum OS version that this version can be installed on.
          min_os: {
            label: 'Minimum OS',
            cli: :o,
            type: :string,
            required: true,
            validate: true,
            default: DEFAULT_MIN_OS,
            changelog: true,
            ted_attribute: :minimumOperatingSystem,
            invalid_msg: "Not a valid OS version! Cannont be empty or '#{Xolo::NONE}'",
            desc: <<~ENDDESC
              The lowest version of macOS able to run this version of this title. Required, will be #{DEFAULT_MIN_OS} if not specified.
            ENDDESC
          },

          # @!attribute max_os
          #   @return [String] The maximum OS version that this version can be installed on.
          max_os: {
            label: 'Maximum OS',
            cli: :O,
            type: :string,
            validate: true,
            changelog: true,
            # default: Xolo::NONE,
            invalid_msg: 'Not a valid OS version!',
            desc: <<~ENDDESC
              The highest version of macOS able to run this version of this title.
            ENDDESC
          },

          # @!attribute reboot
          #   @return [Boolean] Does this version need a reboot after installing?
          reboot: {
            label: 'Reboot',
            cli: :r,
            type: :boolean,
            validate: :validate_boolean,
            ted_attribute: :reboot,
            changelog: true,
            desc: <<~ENDDESC
              The installation of this version requires the computer to reboot. Users will be notified before installation.
            ENDDESC
          },

          # @!attribute standalone
          #   @return [Boolean] Is this version a full installer? (if not, its an incremental patch)
          standalone: {
            label: 'Standalone',
            cli: :s,
            type: :boolean,
            validate: :validate_boolean,
            ted_attribute: :standalone,
            changelog: true,
            desc: <<~ENDDESC
              The installer for this version is a full installer, not an incremental patch that must be installed on top of an earlier version.
            ENDDESC
          },

          # @!attribute killapps
          #   @return [Array<String>] The apps that cannot be running when this version is installed
          killapps: {
            label: 'KillApps',
            cli: :k,
            type: :string,
            multi: true,
            validate: true,
            changelog: true,
            # default: Xolo::NONE,
            invalid_msg: 'Not a valid killapp!',
            desc: <<~ENDDESC
              A killapp is an application that cannot be running while this version is installed.
              If running, installation is delayed, and users are notified to quit.

              Killapps are defined by an app name e.g. 'Google Chrome.app', and the app's Bundle ID
              e.g. 'com.google.chrome'.

              Specify them together separated by a semi-colon, e.g.
                 'Google Chrome.app;com.google.chrome'

              If the title for this version has a defined --app-name and --app-bundle-id, you can
              use them as a killapp by specifying '#{USE_TITLE_FOR_KILLAPP}'

              If not using --walkthru you can use --killapps multiple times
            ENDDESC
          },

          # @!attribute pilot_groups
          #   @return [Array<String>] Jamf groups that will automatically get this version installed or
          #     updated for piloting
          pilot_groups: {
            label: 'Pilot Computer Groups',
            # default: Xolo::NONE,
            cli: :p,
            validate: true,
            type: :string,
            multi: true,
            changelog: true,
            readline_prompt: 'Group Name',
            readline: :jamf_computer_group_names,
            invalid_msg: "Invalid group. Must be an existing Jamf Computer Group, or '#{Xolo::NONE}'.",
            desc: <<~ENDDESC
              One or more Jamf Computer Groups whose members will automatically have this version installed or updated for testing before it is released.

              These computers will be used for testing not just the software, but the installation process itself. Exclusions win, so computers that are also in an excluded group for the title will not be used as pilots.

              When this version is released, the computers in the release_groups defined in the title will automatically have this version installed - and any computers with an older version will have it updated.

              When using the --pilot-groups CLI option, you can specify more than one group by using the option more than once, or by providing a single option value with the groups separated by commas.

              When adding a new version, the pilot groups from the previous version will be inherited if you don't specify any. To make the new version have no pilot groups use '#{Xolo::NONE}'.

              NOTE: Any non-excluded computer can be used for piloting at any time by manually installing the yet-to-be-released version using `sudo xolo install <title> <version>`.  The members of the pilot groups are just the ones that will have it auto-installed.
            ENDDESC
          },

          # @!attribute jamf_pkg
          #   @return [String] The file name of the installer for the Jamf Package object that
          #     installs this version.  'xolo-<title>-<version>.pkg' (or .zip)
          pkg_to_upload: {
            label: 'Upload Package',
            type: :string,
            required: true,
            cli: :u,
            validate: true,
            readline: :get_files,
            do_not_inherit: true,
            hide_from_info: true,
            invalid_msg: 'Invalid installer pkg. Must exist locally and be a .pkg file, or a .zip compressed old-style bundle package.',
            desc: <<~ENDDESC
              The path to a local copy of the installer package for this version. Will be uploaded to Xolo and then Jamf Pro, distribution point(s), replacing any previously uploaded.

              Must be a flat .pkg file, or a .zip compressed old-style bundle package.

              It will be renamed to 'xolo-<title>-<version>.pkg' (or .zip).
              If your Xolo server is confiured to sign unsigned packages, it will do so along the way.
            ENDDESC
          },

          # @!attribute status
          #   @return [String] One of: STATUS_PENDING, STATUS_PILOT, STATUS_RELEASED,
          #     STATUS_SKIPPED, or STATUS_DEPRECATED
          status: {
            label: 'Status',
            type: :symbol,
            do_not_inherit: true,
            cli: false,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              The status of this version in Xolo:
              - pending: Not yet available for installation.
              - pilot: Can be installed for piloting, will auto install on any pilot-groups.
              - released: This is the current version, generally available, will auto-install on target groups.
              - skipped: Was created, and maybe piloted, but never released.
              - deprecated: Was released, but a newer version has since been released.
            ENDDESC
          },

          # @!attribute created_by
          #   @return [String] The login of the admin who created this version.
          created_by: {
            label: 'Created By',
            type: :string,
            do_not_inherit: true,
            cli: false,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              The login of the admin who created this version.
            ENDDESC
          },

          # @!attribute creation_date
          #   @return [Time] The date this version was created.
          creation_date: {
            label: 'Creation Date',
            type: :time,
            do_not_inherit: true,
            cli: false,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              When this version was created.
            ENDDESC
          },

          # @!attribute modified_by
          #   @return [String] The login of the admin who last modified this version.
          modified_by: {
            label: 'Modified By',
            type: :string,
            cli: false,
            do_not_inherit: true,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              The login of the admin who last modified this version.
            ENDDESC
          },

          # @!attribute modification_date
          #   @return [Time] The date this version was last modified.
          modification_date: {
            label: 'Modification Date',
            type: :time,
            cli: false,
            do_not_inherit: true,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              When this version was last modified.
            ENDDESC
          },

          # @!attribute deployed_by
          #   @return [String] The login of the admin who released this version in Xolo.
          #     This is when the Xolo sets the status of this version to 'released', making it
          #     no longer 'in pilot' and the one to be installed or updated by default.
          released_by: {
            label: 'Released By',
            type: :string,
            cli: false,
            do_not_inherit: true,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              The login of the admin who released this version in Xolo.
              This is when the Xolo sets the status of this version to 'released', making it
              no longer 'in pilot' and the one to be installed or updated by default.
            ENDDESC
          },

          # @!attribute release_date
          #   @return [Time] The timestamp this version was released in Xolo.
          #     This is when the Xolo sets the status of this version to 'released', making it
          #     no longer 'in pilot' and the one to be installed or updated by default.
          release_date: {
            label: 'Release Date',
            type: :time,
            cli: false,
            do_not_inherit: true,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              When this version was released in Xolo.
              This is when the Xolo sets the status of this version to 'released', making it
              no longer 'in pilot' and the one to be installed or updated by default.
            ENDDESC
          },

          # @!attribute deprecated_by
          #   @return [String] The login of the admin who deprecated this version in Xolo by releasing
          #     a newer version.
          deprecated_by: {
            label: 'Deprecated By',
            type: :string,
            cli: false,
            do_not_inherit: true,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              The login of the admin who deprecated this version in Xolo by releasing a newer version.
            ENDDESC
          },

          # @!attribute deprecation_date
          #   @return [Time] The timestamp this version was deprecated in Xolo.
          #     This is when the Xolo sets the status of this version to 'deprecated', meaning
          #     it was released, but a newer version has since been released.
          deprecation_date: {
            label: 'Deprecation Date',
            type: :time,
            cli: false,
            do_not_inherit: true,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              When this version was deprecated in Xolo.
              This is when the Xolo sets the status of this version to 'deprecated', which is when a newer version has been released.
              It will still be available for manual installation until it is deleted.
              Deletion is automatic after a period of time, unless the server is configured otherwise.
            ENDDESC
          },

          # @!attribute skipped_by
          #   @return [String] The login of the admin who skipped this version in Xolo by releasing
          #     a newer version.
          skipped_by: {
            label: 'Skipped By',
            type: :string,
            cli: false,
            do_not_inherit: true,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              The login of the admin who skipped this version in Xolo by releasing a newer version.
            ENDDESC
          },

          # @!attribute skipped_date
          #   @return [Time] The timestamp this version was skipped in Xolo.
          #     This is when the Xolo sets the status of this version to 'skipped', meaning
          #     it was never released in Xolo, and now a newer version has been released.
          skipped_date: {
            label: 'Skipped Date',
            type: :time,
            cli: false,
            do_not_inherit: true,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              When this version was skipped in Xolo.
              This is when the Xolo sets the status of this version to 'skipped', meaning it was never released in Xolo, and now a newer version has been released.
              It will be automatically deleted at the next nightly cleanup, unless the server is configured otherwise.
            ENDDESC
          },

          # @!attribute jamf_pkg_name
          #   @return [String] The display name of the Jamf Package object that installs this version.
          #     'xolo-<title>-<version>'
          jamf_pkg_name: {
            label: 'Jamf Package',
            type: :string,
            do_not_inherit: true,
            cli: false,
            desc: <<~ENDDESC
              The display name of the Jamf Package object that installs this version. 'xolo-<title>-<version>'
            ENDDESC
          },

          # @!attribute jamf_pkg_id
          #   @return [String] The id of the Jamf Package object that installs this version.
          #      This is an integer in a string, as are all IDs in the Jamf Pro API.
          jamf_pkg_id: {
            label: 'Jamf Package',
            type: :string,
            read_only: true,
            do_not_inherit: true,
            cli: false,
            desc: <<~ENDDESC
              The id of the Jamf Package object that installs this version. 'xolo-<title>-<version>'
            ENDDESC
          },

          # @!attribute jamf_pkg_file
          #   @return [String] The file name of the installer.pkg file used by the Jamf Package object to
          #    installs this version. 'xolo-<title>-<version>.pkg' (or .zip)
          jamf_pkg_file: {
            label: 'Jamf Package File',
            type: :string,
            do_not_inherit: true,
            cli: false,
            desc: <<~ENDDESC
              The installer filename of the Jamf Package object that installs this version: 'xolo-<title>-<version>.pkg' (or .zip).
            ENDDESC
          },

          # @!attribute dist_pkg
          #   @return [Boolean] Is the most recently uploaded package a Distribution package? If so it can be used
          #      for MDM deployment.
          dist_pkg: {
            label: 'Distribution Package',
            type: :boolean,
            do_not_inherit: true,
            cli: false,
            desc: <<~ENDDESC
              If true, the most recently uploaded .pkg file is a flat Distribution package, and can be deployed via MDM using the 'xadm deploy' command. Nil if no pkg was ever uploaded via xolo. Uploading a different .pkg file via other means will not change this value, and may cause the pkg to fail to deploy via MDM.
              This value is set by the server when the pkg is uploaded.
            ENDDESC
          },

          # @!attribute sha_512
          #   @return [String] The SHA512 checksum of the most recently uploaded package
          sha_512: {
            label: 'Package Checksum',
            type: :string,
            do_not_inherit: true,
            cli: false,
            desc: <<~ENDDESC
              The SHA512 checksum of the most recently uploaded package.
              NOTE: The Jamf Server may use an MD5 checksum in the package object.
              This value is set by the server when the pkg is uploaded.
            ENDDESC
          }

        }.freeze

        ATTRIBUTES.each_key do |attr|
          attr_accessor attr
          attr_accessor "new_#{attr}"
        end

        # Constructor
        ######################
        ######################

        # Instance Methods
        ######################
        ######################

        ######################
        def pilot?
          status == STATUS_PILOT
        end

        ######################
        def released?
          status == STATUS_RELEASED
        end

        ######################
        def skipped?
          status == STATUS_SKIPPED
        end

        ######################
        def deprecated?
          status == STATUS_DEPRECATED
        end

        ######################
        def pending?
          status == STATUS_PENDING
        end

      end # class Title

    end # module BaseClasses

  end # module Core

end # module Xolo
