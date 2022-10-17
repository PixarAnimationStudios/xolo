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
      class Title

        # Constants
        #############################

        # The value to use when all computers are the targets
        TARGET_ALL = 'all'

        # Class Methods
        #############################

        # The ATTRIBUTES that are available as CLI & walkthru options
        def self.cli_opts
          @cli_opts ||= ATTRIBUTES.select { |_k, v| v[:cli] }
        end

        # Attributes
        ######################

        # Attributes of Titles.
        #
        # Title attributes have these attributes:
        #
        # - label: [String] to be displayed in admin interaction, walkthru, err msgs
        #    e.g. 'Title ID'
        #
        # - required: [Boolean] Must be provided when making a new title, cannot be
        #   deleted from existing titles.
        #
        # - immutable: [Boolean] This value can only be set when created a new title.
        #   When editing an existing title, it cannot be changed.
        #
        # - cli: [false, Symbol] If this attr. is taken as a CLI option or
        #   walkthru item, what is its 'short' option flag?
        #
        #   If falsey, this option is never taken as a cli
        #   option or walkthru menu choice, but may be used elsewhere,
        #   e.g. in this cli command:
        #      xadm add-title my-title-id <options>
        #   'add-title' is the command and 'my-title-id', which populates th
        #   title_id attribute, is the argument, but not a CLI option, so for
        #   'title_id', cli: is false
        #
        #   If a one-letter Symbol, this is the 'short' cli option, e.g. the Symbol :d
        #   defines the cli option '-d' which is used as the short option for --description
        #   NOTE: the long cli options are just the attrib keys preceded with -- and
        #   underscores converted to dashes, so :title_id becomes --title-id
        #
        #   If the symbol :none is used, there is no short variation of the CLI option.
        #   but a long --option-flag will be used matching the attribute key, e.g.
        #   for app_bundle_id it will be --app-bundle-id
        #
        # - depends: [Symbol] Some other key of the ATTRIBTUES hash. When defined, both the
        #   key named here and the key in which this is defined, must be present together
        #   on the command-line. E.g. Setting  foo: { depends: :bar }, means that if either
        #   --foo or --bar are given on the commandline, the other must also be given.
        #
        # - multi: [Boolean] If true, this option can be given multiple times on the commandline
        #   and all the values will be in an array in the options hash.
        #   E.g. if foo: { multi: true } and these options are given on the commandline
        #       --foo val1 --foo val2  --foo val3
        #   then the options hash will contain: :foo => ['val1', 'val2', 'val3']
        #
        # - type: [Symbol] the data type of the value. One of:
        #   :boolean, :integer, :string, :float, :io, :date.
        #   NOTE: Pluralizing those (except :boolean) means the value is an array of
        #   these objects
        #
        # - default: [String, Numeric, Boolean, nil] the default value if nothing is
        #   provided. Note that titles never inherit values, only versions do.
        #
        # - validate: [Boolean, Symbol] how to validate values for this attribute.
        #   - If true (not just truthy) call method Xolo::Core::Validate.<value_key>
        #     e.g. Xolo::Core::Validate.title_id(val)
        #   - If a Symbol, its a nonstandard method to call on the Xolo::Admin::Validate module
        #     e.g. :non_empty_array will validate the value using
        #     Xolo::Core::Validate.non_empty_array(val)
        #   - Anything else: no validation
        #
        # - invalid_msg: [String] custom message to display when invalid
        #
        # - desc: [String] helpful text explaining what the attribute is, and what its CLI option means.
        #   Displayed during walkthru, in help messages, and in some err messages.
        #
        #
        ATTRIBUTES = {

          title: {
            label: 'Title',
            required: true,
            immutable: true,
            cli: false,
            type: :string,
            validate: true,
            invalid_msg: 'Not a valid title id! Must be lowercase alphanumeric and dashes only, cannot already exist in Xolo.',
            desc: <<~ENDDESC
              A unique string identifying this Title, e.g. 'folio' or 'google-chrome'.
              The same as a 'basename' in d3.
              Must contain only lowercase letters, numbers, and dashes.
            ENDDESC
          },

          display_name: {
            label: 'Display Name',
            required: true,
            cli: :n,
            type: :string,
            validate: :title_display_name,
            invalid_msg: '"Not a valid display name, must be at least three characters, starting and ending with non-whitespace.',
            desc: <<~ENDDESC
              A human-friendly name for the Software Title, e.g. 'Google Chrome', or 'NFS Menubar'. Must be at least three characters long.
            ENDDESC
          },

          description: {
            label: 'Description',
            required: true,
            cli: :d,
            type: :string,
            validate: :title_desc,
            invalid_msg: "Not a valid description name, must be at least 20 characters. Include a useful dscription of what the software does,  URLs, developer names, etc. DO NOT USE, e.g. 'Installs Google Chrome' for the title 'google-chrome', that just wastes everyone's time.",
            desc: <<~ENDDESC
              A useful dscription of what the software installed by this title does. You can also include URLs, developer names, support info, etc.

              DO NOT use, e.g. 'Installs Google Chrome' for the title 'google-chrome', that just wastes everyone's time.
              Must be at least 20 Characters.
            ENDDESC
          },

          publisher: {
            label: 'Publisher',
            required: true,
            cli: :p,
            type: :string,
            validate: true,
            invalid_msg: '"Not a valid Publisher, must be at least three characters.',
            desc: <<~ENDDESC
              The company or entity that publishes this title, e.g. 'Apple, Inc.'
              or 'Pixar Animation Studios'.
            ENDDESC
          },

          app_name: {
            label: 'App Name',
            cli: :a,
            validate: true,
            type: :string,
            invalid_msg: "Not a valid App name, must end with '.app'",
            desc: <<~ENDDESC
              If this title installs a .app bundle, the app's name must be provided.
              This the name of the bundle itself on disk, e.g. 'Google Chrome.app'.

              Jamf Patch Management uses this, plus the app's bundle id, to determine
              if the title is installed on a computer, and if so, which version.

              If the title does not install a .app bundle, leave this blank, and
              provide a --version-script.

              REQUIRED if --app-bundle-id is used.
            ENDDESC
          },

          app_bundle_id: {
            label: 'App Bundle ID',
            cli: :b,
            validate: true,
            type: :string,
            depends: :app_name,
            invalid_msg: '"Not a valid bundle ID, must include at least one dot.',
            desc: <<~ENDDESC
              If this title installs a .app bundle, the app's bundle-id must be provided.
              This is found in the CFBundleIdentifier key of the app's Info.plist.
              e.g. 'com.google.chrome'

              Jamf Patch Management uses this, plus the app's name, to determine
              if the title is installed on a computer, and if so, which version.

              If the title does not install a .app bundle, or if the .app doesn't
              provide its version via the bundle id (e.g. Firefox) leave this blank, and
              provide a --version-script.

              REQUIRED if --app-name is used.
            ENDDESC
          },

          version_script: {
            label: 'Version Script',
            cli: :v,
            validate: true,
            type: :string,
            invalid_msg: 'Invalid Script Path. No such file found locally.',
            desc: <<~ENDDESC
              If this title does NOT install a .app bundle, enter the local path to a script which will run on managed computers and output a <result> tag with the currently installed version of this title.

              E.g. if version 1.2.3 is installed, the script should output the text:
                 <result>1.2.3</result>
              and if no version of the title is installed, it should output:
                 <result></result>

              NOTE: This is ignored if --app-name and --app-bundle-id are used.
            ENDDESC
          },

          target_group: {
            label: 'Target Computer Group',
            default: Xolo::NONE,
            cli: :t,
            validate: :jamf_group,
            type: :string,
            multi: true,
            invalid_msg: "Invalid target group. Must be an existing Jamf Computer Group, '#{TARGET_ALL}', or '#{Xolo::NONE}'.",
            desc: <<~ENDDESC
              The name of a Jamf Computer Group identifying computers that will automatically have this title installed.
              Use '#{TARGET_ALL}' to auto-install on all computers that aren't excluded.
              Use '#{Xolo::NONE}' to remove any current target groups.

              To specify more than one group on the command line, use multiple --target-group options.
              To specify more than one group during --walkthru, separate them with commas.

              NOTE: Titles can always be installed manually (via command line or Self Service) on non-excluded computers.
            ENDDESC
          },

          excluded_group: {
            label: 'Excluded Computer Group',
            cli: :x,
            validate: :jamf_group,
            default: Xolo::NONE,
            type: :string,
            multi: true,
            invalid_msg: "Invalid exclusion. All exclusions must be an existing Jamf Computer Group, or '#{Xolo::NONE}'.",
            desc: <<~ENDDESC
              The name of a Jamf Computer Group identifying computers that will not be able to install this title.
              If a computer is both a target and an exclusion, the exclusion wins and the title will not be available.
              Use '#{Xolo::NONE}' to remove any current excluded groups.

              To specify more than one group on the command line, use multiple --excluded-group options.
              To specify more than one group during --walkthru, separate them with commas.
            ENDDESC
          },

          expiration: {
            label: 'Expire Days',
            cli: :e,
            default: 0,
            validate: /\A\d+\z/,
            type: :integer,
            invalid_msg: 'Invalid expiration period. Must be a non-negative integer number of days. or 0 for no expiration.',
            desc: <<~ENDDESC
              If none of the executables listed as 'Expiration Paths' have been brought to the foreground in this number of days, the title is uninstalled from the computer.

              Zero means 'do not expire'.
            ENDDESC
          },

          expiration_path: {
            label: 'Expiration Path',
            cli: :E,
            validate: true,
            type: :string,
            multi: true,
            invalid_msg: "Invalid expiration path. Must at least one absolute path starting with a '/' and containing at least one more non-adjacent '/'.",
            desc: <<~ENDDESC
              Path to an executable that must come to the foreground of a user's GUI session to be considered 'usage' of this title. If the executable does not come to the foreground during period of days specified by --expiration, the title will be uninstalled.

              If multiple paths are specified, any one of them coming to the foreground will count as usage. This is useful for multi-app titles, such as Microsoft Office.

              To specify more than one path on the command line, use multiple --expiration-path options.
              To specify more than one path during --walkthru, separate them with commas.
            ENDDESC
          },

          self_service: {
            label: 'Show in Self Service',
            cli: :s,
            type: :boolean,
            default: false,
            desc: <<~ENDDESC
              Make this title available in Self Service.
              If there are any defined target groups, the title will only be available to computers in those groups.
              It will never be available to excluded computers.
              Self Service is not available for titles with the target 'all'.
            ENDDESC
          },

          self_service_category: {
            label: 'Self Service Category',
            cli: :c,
            validate: true,
            type: :string,
            invalid_msg: 'Invalid category. Must exist in Jamf Pro.',
            desc: <<~ENDDESC
              The Category in which to display this title in Self Service.
              Ignored if not in Self Service.
            ENDDESC
          },

          self_service_icon: {
            label: 'Self Service Icon',
            cli: :i,
            validate: true,
            type: :string,
            invalid_msg: 'Invalid Icon Path. No such file found locally.',
            desc: <<~ENDDESC
              Path to a local image file to use as the icon for this title in Self Service.
              Ignored if not in Self Service.
            ENDDESC
          },

          created_by: {
            label: 'Created By',
            type: :string,
            cli: false,
            desc: <<~ENDDESC
              The login of the admin who created this title.
            ENDDESC
          },

          creation_date: {
            label: 'Creation Date',
            type: :time,
            cli: false,
            desc: <<~ENDDESC
              The date this title was created.
            ENDDESC
          },

          modified_by: {
            label: 'Modified By',
            type: :string,
            cli: false,
            desc: <<~ENDDESC
              The login of the admin who last modified this title.
            ENDDESC
          },

          modification_date: {
            label: 'Creation Date',
            type: :time,
            cli: false,
            desc: <<~ENDDESC
              The date this title was last modified.
            ENDDESC
          }

        }.freeze

        ATTRIBUTES.keys.each do |attr|
          attr_accessor attr
          attr_accessor "new_#{attr}"
        end

        # Constructor
        ######################
        def initialize(data_hash)
          data_hash.each { |k, v| instance_variable_set "@#{k}", v }
        end

      end # class Title

    end # module BaseClasses

  end # module Core

end # module Xolo
