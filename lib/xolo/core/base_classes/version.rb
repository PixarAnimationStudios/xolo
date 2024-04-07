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

        # Class Methods
        #############################

        # The ATTRIBUTES that are available as CLI & walkthru options
        def self.cli_opts
          @cli_opts ||= ATTRIBUTES.select { |_k, v| v[:cli] }
        end

        # Attributes
        ######################

        # Attributes of Versions
        # See the definition for Xolo::Core::BaseClasses::Title::ATTRIBUTES
        ATTRIBUTES = {
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

          publish_date: {
            label: 'Publish Date',
            type: :string,
            required: true,
            cli: :d,
            validate: true,
            default: Date.today.to_s,
            invalid_msg: 'Not a valid date!',
            desc: <<~ENDDESC
              The date this version was released by the publisher.
              Default is today.
            ENDDESC
          },

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

          reboot: {
            label: 'Reboot',
            cli: :r,
            type: :boolean,
            validate: :boolean,
            desc: <<~ENDDESC
              The installation of this version requires the computer to reboot. Users will be notified before installation.
            ENDDESC
          },

          standalone: {
            label: 'Standalone',
            cli: :s,
            type: :boolean,
            validate: :boolean,
            desc: <<~ENDDESC
              The installer for this version is a full installer, not an incremental patch that must be installed on top of an earlier version.
            ENDDESC
          },

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
              (see '#{Xolo::Admin.executable.basename} help add-title')

              To specify more than one killapp separate them with commas. If not using --walkthru you can
              also use the CLI option multiple times.
            ENDDESC
          },

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

          status: {
            label: 'Status',
            type: :symbol,
            cli: false,
            desc: <<~ENDDESC
              :pilot, :released, :skipped, :deprecated
            ENDDESC
          },

          created_by: {
            label: 'Created By',
            type: :string,
            cli: false,
            desc: <<~ENDDESC
              The login of the admin who created this version.
            ENDDESC
          },

          creation_date: {
            label: 'Creation Date',
            type: :time,
            cli: false,
            desc: <<~ENDDESC
              The date this version was created.
            ENDDESC
          },

          modified_by: {
            label: 'Modified By',
            type: :string,
            cli: false,
            desc: <<~ENDDESC
              The login of the admin who last modified this version.
            ENDDESC
          },

          modification_date: {
            label: 'Creation Date',
            type: :time,
            cli: false,
            desc: <<~ENDDESC
              The date this version was last modified.
            ENDDESC
          },

          released_by: {
            label: 'Released By',
            type: :string,
            cli: false,
            desc: <<~ENDDESC
              The login of the admin who released this version in Xolo.
            ENDDESC
          },

          release_date: {
            label: 'Creation Date',
            type: :time,
            cli: false,
            desc: <<~ENDDESC
              The date this version was last released in Xolo.
            ENDDESC
          },

          jamf_pkg: {
            label: 'Jamf Package',
            type: :string,
            cli: false,
            desc: <<~ENDDESC
              The display name of the Jamf::Package object that installs this version.
            ENDDESC
          }

        }.freeze

        ATTRIBUTES.keys.each do |attr|
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
