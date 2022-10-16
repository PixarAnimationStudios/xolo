# Copyright 2022 Pixar
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
      # These are simpler objects than Windu::SoftwareTitle instances.
      # The Xolo server will translate between the two.
      #
      class Version

        # Constants
        #############################

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
              A unique version string identifying this version in this title,
              e.g. '12.34.5'.
            ENDDESC
          },

          publish_date: {
            label: 'Publish Date',
            type: :date,
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
              Leave blank or set to 'none' if not applicable.
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
              Leave blank or set to 'none' if not applicable.
            ENDDESC
          },

          reboot: {
            label: 'Reboot',
            cli: :r,
            type: :boolean,
            desc: <<~ENDDESC
              The installation of this version requires the computer to reboot.
            ENDDESC
          },

          standalone: {
            label: 'Standalone',
            cli: :s,
            type: :boolean,
            desc: <<~ENDDESC
              The installer for this version is a full installer, not an incremental patch
              that must be installed on top of an earlier version.
            ENDDESC
          },

          kill_apps: {
            label: 'Kill Apps',
            cli: :k,
            type: :strings,
            validate: true,
            default: Xolo::NONE,
            invalid_msg: 'Not a valid OS version!',
            desc: <<~ENDDESC
              A killapp is an application that cannot be running while this version is installed.
              If running, installation is delayed, and users are notified to quit.
              They are defined by an app name e.g. 'Google Chrome.app', and the app's Bundle ID
              e.g. 'com.google.chrome'.
              Specify them together separated by a semi-colon, e.g. 'Google Chrome.app;com.google.chrome'
              To specify more than one killapp, separate them by commas, or use -k more than once.
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
