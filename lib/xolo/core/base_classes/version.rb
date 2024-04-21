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

  module Core

    module BaseClasses

      # The base class for dealing with Titles in the
      # Xolo Server and the Admin modules.
      #
      # These are simpler objects than Windoo::SoftwareTitle instances.
      # The Xolo server will translate between the two.
      #
      class Version

        # Constants
        #############################

        USE_TITLE_FOR_KILLAPP = 'use-title'

        # Attributes
        ######################

        # Attributes of Versions
        # See the definition for Xolo::Core::BaseClasses::Title::ATTRIBUTES
        ATTRIBUTES = {

          # @!attribute version
          #   @return [String] The version-string for this version.
          version: {
            label: 'Version',
            required: true,
            immutable: true,
            cli: false,
            type: :string,
            validate: true,
            invalid_msg: 'Not a valid version! Cannot already exist in this title.',
            desc: <<~ENDDESC
              A unique version string identifying this version in this title, e.g. '12.34.5'.
            ENDDESC
          },

          # @!attribute publish_date
          #   @return [Time] When the publisher released this version
          publish_date: {
            label: 'Publish Date',
            type: :time,
            required: true,
            cli: :d,
            validate: true,
            default: Time.now,
            invalid_msg: 'Not a valid date!',
            desc: <<~ENDDESC
              The date this version was released by the publisher.
              Default is today.
            ENDDESC
          },

          # @!attribute min_os
          #   @return [String] The minimum OS version that this version can be installed on.
          min_os: {
            label: 'Minimum OS',
            cli: :o,
            type: :string,
            validate: true,
            default: Xolo::NONE,
            invalid_msg: 'Not a valid OS version!',
            desc: <<~ENDDESC
              The lowest version of macOS able to run this version of this title.
              Leave blank or set to '#{Xolo::NONE}' if not applicable.
            ENDDESC
          },

          # @!attribute max_os
          #   @return [String] The maximum OS version that this version can be installed on.
          max_os: {
            label: 'Maximum OS',
            cli: :O,
            type: :string,
            validate: true,
            default: Xolo::NONE,
            invalid_msg: 'Not a valid OS version!',
            desc: <<~ENDDESC
              The highest version of macOS able to run this version of this title.
              Leave blank or set to '#{Xolo::NONE}' if not applicable.
            ENDDESC
          },

          # @!attribute reboot
          #   @return [Boolean] Does this version need a reboot after installing?
          reboot: {
            label: 'Reboot',
            cli: :r,
            type: :boolean,
            validate: :validate_boolean,
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
            desc: <<~ENDDESC
              The installer for this version is a full installer, not an incremental patch that must be installed on top of an earlier version.
            ENDDESC
          },

          # @!attribute killapps
          #   @return [Array<String>] The apps that cannot be running when this version is installed
          killapps: {
            label: 'KillApp',
            cli: :k,
            type: :string,
            multi: true,
            validate: true,
            default: Xolo::NONE,
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

              To specify more than one killapp separate them with commas. If not using --walkthru you can
              also use the CLI option multiple times.
            ENDDESC
          },

          # @!attribute pilot_groups
          #   @return [Array<String>] Jamf groups that will automatically get this version for piloting
          pilot_groups: {
            label: 'Pilot Computer Groups',
            default: Xolo::NONE,
            cli: :p,
            validate: true,
            type: :string,
            multi: true,
            invalid_msg: "Invalid pilot group. Must be an existing Jamf Computer Group, or '#{Xolo::NONE}'.",
            desc: <<~ENDDESC
              One or more Jamf Computer Groups containing computers that will automatically have this title installed before it is released.

              These computers will be used for testing not just the software, but the installation process itself. Computers that are also in an excluded group for the title will not be used as pilots.

              To specify more than one group separate them with commas. If not using --walkthru you can
              also use the CLI option multiple times.
            ENDDESC
          },

          # @!attribute status
          #   @return [symbol] One of: :pilot, :released, :skipped, :deprecated
          status: {
            label: 'Status',
            type: :symbol,
            cli: false,
            desc: <<~ENDDESC
              :pilot, :released, :skipped, :deprecated
            ENDDESC
          },

          # @!attribute created_by
          #   @return [String] The login of the admin who created this version.
          created_by: {
            label: 'Created By',
            type: :string,
            cli: false,
            desc: <<~ENDDESC
              The login of the admin who created this version.
            ENDDESC
          },

          # @!attribute creation_date
          #   @return [Time] The date this version was created.
          creation_date: {
            label: 'Creation Date',
            type: :time,
            cli: false,
            desc: <<~ENDDESC
              The date this version was created.
            ENDDESC
          },

          # @!attribute modified_by
          #   @return [String] The login of the admin who last modified this version.
          modified_by: {
            label: 'Modified By',
            type: :string,
            cli: false,
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
            desc: <<~ENDDESC
              The date this version was last modified.
            ENDDESC
          },

          # @!attribute released_by
          #   @return [String] The login of the admin who piloted this version in Xolo.
          #     This is when the Title Editor, or other Patch Source, tells Jamf Pro that
          #     this new version is available and can be piloted.
          piloted_by: {
            label: 'Piloted By',
            type: :string,
            cli: false,
            desc: <<~ENDDESC
              The login of the admin who piloted this version in Xolo.
              This is when the Title Editor, or other Patch Source, tells Jamf Pro that
              this new version is available. Versions should be piloted before they are
              released.
            ENDDESC
          },

          # @!attribute release_date
          #   @return [Time] The timestamp this version was released in Xolo.
          #     This is when the Title Editor, or other Patch Source, tells Jamf Pro that
          #     this new version is available and can be piloted.
          pilot_date: {
            label: 'Release Date',
            type: :time,
            cli: false,
            desc: <<~ENDDESC
              The timestamp when this version was piloted in Xolo.
              This is when the Title Editor, or other Patch Source, tells Jamf Pro that
              this new version is available. Versions should be piloted before they are
              released.
            ENDDESC
          },

          # @!attribute deployed_by
          #   @return [String] The login of the admin who released this version in Xolo.
          #     This is when the Xolo sets the status of this version to 'released', making it
          #     no longer 'in pilot' and the one to be installed or updated by default.
          released_by: {
            label: 'Deployed By',
            type: :string,
            cli: false,
            desc: <<~ENDDESC
              The login of the admin who released this version in Xolo.
              This is when the Xolo sets the status of this version to 'released', making it
              no longer 'in pilot' and the one to be installed or updated by default.
            ENDDESC
          },

          # @!attribute deploy_date
          #   @return [Time] The timestamp this version was released in Xolo.
          #     This is when the Xolo sets the status of this version to 'released', making it
          #     no longer 'in pilot' and the one to be installed or updated by default.
          release_date: {
            label: 'Deployt Date',
            type: :time,
            cli: false,
            desc: <<~ENDDESC
              The timestamp when this version was released in Xolo.
              This is when the Xolo sets the status of this version to 'released', making it
              no longer 'in pilot' and the one to be installed or updated by default.
            ENDDESC
          },

          # @!attribute jamf_pkg
          #   @return [String] The display name of the Jamf::Package object that installs this version.
          jamf_pkg: {
            label: 'Jamf Package',
            type: :string,
            cli: false,
            desc: <<~ENDDESC
              The display name of the Jamf::Package object that installs this version.
            ENDDESC
          }

        }.freeze

        ATTRIBUTES.each_key do |attr|
          attr_accessor attr
          attr_accessor "new_#{attr}"
        end

        # Constructor
        ######################
        def initialize(json_data); end

      end # class Title

    end # module BaseClasses

  end # module Core

end # module Xolo
