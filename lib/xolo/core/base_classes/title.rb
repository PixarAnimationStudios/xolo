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

  module Core

    module BaseClasses

      # The base class for dealing with Titles in the
      # Xolo Server and the Admin modules.
      #
      # These are simpler objects than Windoo::SoftwareTitle instances.
      # The Xolo server will translate between the two.
      #
      class Title < Xolo::Core::BaseClasses::ServerObject

        # Mixins
        #############################
        #############################

        # Constants
        #############################
        #############################

        # The value to use when all computers are the targets
        TARGET_ALL = 'all'

        # Attributes
        ######################
        ######################

        # Attributes of Titles.
        #
        # This hash defines the attributes of all Xolo titles. Each key is the name
        # of an attribute, and the values are hashes defining the details of that
        # attribute.
        #
        # These attributes are also used to create/define CLI & walkthru options for
        # title-relatead commands.
        #
        # Subclasses of Xolo::Core::BaseClasses::Title will define other attributes
        # as needed, usually as accessors.
        #
        # Title attributes have these details:
        #
        # - label: [String] to be displayed in admin interaction, walkthru, help msgs
        #    or error messages. e.g. 'Display Name'
        #
        # - required: [Boolean] Must be provided when making a new title, cannot be
        #   deleted from existing titles. (but can be changed if not immutable)
        #
        # - immutable: [Boolean] This value can only be set when creatimg a new title.
        #   When editing an existing title, it cannot be changed.
        #
        # - cli: [Symbol, false] What is the 'short' option flag for this option?
        #   The long option flag is the key, preceded with '--' and with underscores
        #   changed to '-', so display_name is set using the cli option '--display-name'.
        #   If this is set to :n  then the short version is '-n'
        #
        #   If this attribute can't be set via walk thru or a CLI option, set this to false.
        #
        # - multi: [Boolean] If true, this option takes multiple values and is stored as
        #   an Array. On the commandline, it can be given multiple times and all the values
        #   will be in an array in the options hash.
        #   E.g. if foo: { multi: true } and these options are given on the commandline
        #       --foo val1 --foo val2  --foo 'val 3'
        #   then the options hash will contain: :foo => ['val1', 'val2', 'val 3']
        #   It can also be given as a single comma-separated string, e.g.
        #       --foo 'val1, val2, val 3'
        #
        #   In --walkthru the user will be asked to keep entering values, and to
        #   end input with an 'x' by itself.
        #
        # - default: [String, Numeric, Boolean, Proc] the default value if nothing is
        #   provided or inherited. Note that titles never inherit values, only versions do.
        #
        # - validate: [Boolean, Symbol] how to validate & convert values for this attribute.
        #
        #   - If true (not just truthy) call method named 'validate_<key>' in  Xolo::Admin::Validate
        #     passing in the value to validate.
        #     e.g. Xolo::Admin::Validate.validate_display_name(new_display_name)
        #
        #   - If a Symbol, it's an arbitrary method to call on the Xolo::Admin::Validate module
        #     e.g. :non_empty_array will validate the value using
        #     Xolo::Admin::Validate.non_empty_array(some_array_value)
        #
        #   - Anything else: no validation, and the value will be a String
        #
        # - type: [Symbol] the data type of the value. One of: :boolean, :string, :integer,
        #   :time
        #
        #   NOTE: We are not using Optimist's validation & auto-conversion of these types, they
        #   all come from the CLI as strings, and the matching methods in Xolo::Admin::Validate
        #   is used to validate and convert the values.
        #   The YARD docs for each attribute indicate the Class of the value in the
        #   Title object after CLI processing.
        #
        # - invalid_msg: [String] custom message to display when the value fails validation.
        #
        # - desc: [String] Helpful text explaining what the attribute is, and what its CLI option means.
        #   Displayed during walkthru, in help messages, and in some err messages.
        #
        # - walkthru_na: [Symbol] The name of a method to call (usually defined in Xolo::Admin::Interactive)
        #   when building the walk thru menu item for this option.
        #   If it returns a string, it is an explanation of wny this option
        #   is not available at the moment, and the item is not selectable. If it returns nil, the
        #   item is displayed and handled as normal.
        #
        # - multiline [Boolean] If true, the value for this option can be many lines lione, and in
        #   walkthru, will be presented to the user in an editor like vim. See also multi: above
        #
        # - title_editor_attribute: [Symbol] If this attribute has a matching one on the related
        #   Title Editor Title, this is the name of that attribute in the Windoo::SoftwareTitle
        #
        # - readline: [Symbol] If set, use readline to get the value from the user during walkthru.
        #   If the symbol is :get_files, a custom method that uses readline with shell-style auto-
        #   complete to get one or more file paths.
        #   Any other symbol is the name of a method to call, which will return an array of possible
        #   values for the option, which will be used for readline-based auto-completion.
        #
        # - readline_prompt: When using readline to gather mulit: values, this prompt is shown at the
        #   start of each line of input for the next item.
        #
        # - read_only: [Boolean] defaults to false. When true, the server maintains this value, and
        #   its only readable via xadm.
        #
        #
        ATTRIBUTES = {

          # @!attribute title
          #   @return [String] The unique title-string for this title.
          title: {
            label: 'Title',
            title_editor_attribute: :id,
            required: true,
            immutable: true,
            cli: false,
            type: :string,
            validate: true,
            invalid_msg: 'Not a valid title: must be lowercase alphanumeric and dashes only',
            desc: <<~ENDDESC
              A unique string identifying this Title, e.g. 'folio' or 'google-chrome'.
              The same as a 'basename' in d3.
              Must contain only lowercase letters, numbers, and dashes.
            ENDDESC
          },

          # @!attribute display_name
          #   @return [String] The display-name for this title
          display_name: {
            label: 'Display Name',
            title_editor_attribute: :name,
            required: true,
            cli: :n,
            type: :string,
            validate: :validate_title_display_name,
            invalid_msg: 'Not a valid display name, must be at least three characters long.',
            desc: <<~ENDDESC
              A human-friendly name for the Software Title, e.g. 'Google Chrome', or 'NFS Menubar'.
              Must be at least three characters long.
            ENDDESC
          },

          # @!attribute description
          #   @return [String] A description of what this title installs
          description: {
            label: 'Description',
            required: true,
            cli: :d,
            type: :string,
            validate: :validate_title_desc,
            multiline: true,
            invalid_msg: <<~ENDINV,
              Not a valid description, must be at least 20 characters.

              Provide a useful dscription of what the software does, URLs, developer names, etc.

              DO NOT USE, e.g. 'Installs Some App', because we know that already and it isn't helpful.
            ENDINV
            desc: <<~ENDDESC
              A useful dscription of what the software installed by this title does. You can also include URLs, developer names, support info, etc.

              DO NOT use, e.g. 'Installs Some App', because we know that already and it isn't helpful.

              Must be at least 20 Characters.
            ENDDESC
          },

          # @!attribute publisher
          #   @return [String] The entity that publishes this title
          publisher: {
            label: 'Publisher',
            title_editor_attribute: :publisher,
            required: true,
            cli: :p,
            type: :string,
            validate: true,
            invalid_msg: '"Not a valid Publisher, must be at least three characters.',
            desc: <<~ENDDESC
              The company or entity that publishes this title, e.g. 'Apple, Inc.' or 'Pixar Animation Studios'.
            ENDDESC
          },

          # @!attribute app_name
          #   @return [String] The name of the .app installed by this title. Nil if no .app is installed
          app_name: {
            label: 'App Name',
            title_editor_attribute: :appName,
            cli: :a,
            validate: true,
            type: :string,
            walkthru_na: :app_name_bundleid_na,
            invalid_msg: "Not a valid App name, must end with '.app'",
            desc: <<~ENDDESC
              If this title installs a .app bundle, the app's name must be provided. This the name of the bundle itself on disk, e.g. 'Google Chrome.app'.

              Jamf Patch Management uses this, plus the app's bundle id, to determine if the title is installed on a computer, and if so, which version.

              If the title does not install a .app bundle, leave this blank, and provide a --version-script.

              REQUIRED if --app-bundle-id is used.
            ENDDESC
          },

          # @!attribute app_bundle_id
          #   @return [String] The bundle ID of the .app installed by this title. Nil if no .app is installed
          app_bundle_id: {
            label: 'App Bundle ID',
            title_editor_attribute: :bundleId,
            cli: :b,
            validate: true,
            type: :string,
            walkthru_na: :app_name_bundleid_na,
            invalid_msg: '"Not a valid bundle-id, must include at least one dot.',
            desc: <<~ENDDESC
              If this title installs a .app bundle, the app's bundle-id must be provided. This is found in the CFBundleIdentifier key of the app's Info.plist, e.g. 'com.google.chrome'

              Jamf Patch Management uses this, plus the app's name, to determine if the title is installed on a computer, and if so, which version.

              If the title does not install a .app bundle, or if the .app doesn't provide its version via the bundle id (e.g. Firefox) leave this blank, and provide a --version-script.

              REQUIRED if --app-name is used.
            ENDDESC
          },

          # @!attribute version_script
          #   @return [String] A script that will return the currently installed version of this
          #      title on a client mac
          version_script: {
            label: 'Version Script',
            cli: :v,
            validate: true,
            type: :string,
            readline: :get_files,
            walkthru_na: :version_script_na,
            invalid_msg: "Invalid Script Path. Local File must exist and start with '#!'.",
            desc: <<~ENDDESC
              If this title does NOT install a .app bundle, enter the local path to a script which will run on managed computers and output a <result> tag with the currently installed version of this title.

              E.g. if version 1.2.3 is installed, the script should output the text:
                 <result>1.2.3</result>
              and if no version of the title is installed, it should output:
                 <result></result>

              NOTE: This cannot be used if --app-name & --app-bundle-id are used, but must be used if they are not
            ENDDESC
          },

          # TODO: make it so that when a xoloadmin says target_group = all, an optional policy
          # is run that requests approval for that.  That policy can run a script to do ... anything
          # but until the approval is granted, the target_group is an empty array
          #
          # @!attribute target_groups
          #   @return [Array<String>] Jamf groups that will automatically get this title installed when released
          target_groups: {
            label: 'Target Computer Groups',
            cli: :t,
            cli_alias: :target_group,
            validate: true,
            type: :string,
            multi: true,
            readline_prompt: 'Group Name',
            readline: :jamf_computer_group_names,
            invalid_msg: 'Invalid target computer group(s). Must exist in Jamf.',
            desc: <<~ENDDESC
              One or more Jamf Computer Groups containing computers that will automatically have this title installed.
              Use '#{TARGET_ALL}' to auto-install on all computers that aren't excluded.

              NOTE: Titles can always be installed manually (via command line or Self Service) on non-excluded computers. It's OK to have no target groups.

              If not using --walkthru you can use --target-groups multiple times.
            ENDDESC
          },

          # @!attribute excluded_groups
          #   @return [Array<String>] Jamf groups that are not allowed to install this title
          excluded_groups: {
            label: 'Excluded Computer Groups',
            cli: :x,
            validate: true,
            type: :string,
            multi: true,
            readline_prompt: 'Group Name',
            readline: :jamf_computer_group_names,
            invalid_msg: 'Invalid excluded computer group(s). Must exist in Jamf.',
            desc: <<~ENDDESC
              One or more Jamf Computer Groups containing computers that are not allowed to install this title.
              If a computer is both a target and an exclusion, the exclusion wins and the title will not be available.

              If not using --walkthru you can use --excluded-groups multiple times.
            ENDDESC
          },

          # @!attribute expiration
          #   @return [Integer] Number of days of disuse before the title is uninstalled.
          expiration: {
            label: 'Expire Days',
            cli: :e,
            validate: true,
            type: :integer,
            invalid_msg: 'Invalid expiration period. Must be a non-negative integer number of days. or 0 for no expiration.',
            desc: <<~ENDDESC
              If none of the executables listed as 'Expiration Paths' have been brought to the foreground in this number of days, the title is uninstalled from the computer.

              Unsetting this value, or setting it to zero, means 'do not expire'.
            ENDDESC
          },

          # @!attribute expiration_paths
          #   @return [Array<String>] Paths to executables that, when in the foreground,
          #      are considerd 'use' if this title, WRT expiration.
          expiration_paths: {
            label: 'Expiration Paths',
            cli: :E,
            validate: true,
            type: :string,
            multi: true,
            walkthru_na: :expiration_na,
            readline: :get_files,
            readline_prompt: 'Path',
            invalid_msg: "Invalid expiration path. Must start with a '/' and contain at least one more non-adjacent '/'.",
            desc: <<~ENDDESC
              One or more paths to executables that must come to the foreground of a user's GUI session to be considered 'usage' of this title. If the executable does not come to the foreground during period of days specified by --expiration, the title will be uninstalled.

              If multiple paths are specified, any one of them coming to the foreground will count as usage. This is useful for multi-app titles, such as Microsoft Office.

              These paths do not need to exist on this computer.

              If not using --walkthru you can use --expiration-paths multiple times.
            ENDDESC
          },

          # @!attribute self_service
          #   @return [Boolean] Does this title appear in Self Service?
          self_service: {
            label: 'In Self Service?',
            cli: :s,
            type: :boolean,
            validate: :validate_boolean,
            default: false,
            walkthru_na: :ssvc_na,
            desc: <<~ENDDESC
              Make this title available in Self Service.
              If there are any defined target groups, the title will only be available to computers in those groups.
              It will never be available to excluded computers.
              Self Service is not available for titles with the target 'all'.
            ENDDESC
          },

          # @!attribute self_service_category
          #   @return [String] The main Self Service category in which to show this title
          self_service_category: {
            label: 'Self Service Category',
            cli: :c,
            validate: true,
            type: :string,
            walkthru_na: :ssvc_na,
            readline: :jamf_category_names,
            invalid_msg: 'Invalid category. Must exist in Jamf Pro.',
            desc: <<~ENDDESC
              The Category in which to display this title in Self Service.
              Ignored if not in Self Service.

              REQUIRED if self_service is true, ignored otherwise
            ENDDESC
          },

          # NOTE: This isn't stored anywhere after its used. If it is provided via
          # xadm add-title or edit-title, it will be uploaded and applied at that
          # time, but then if you fetch the title again, this value will be nil.
          #
          # @!attribute self_service_icon
          #   @return [String] Path to a local image file to use as the Self Service icon for this title.
          self_service_icon: {
            label: 'Self Service Icon',
            cli: :i,
            validate: true,
            type: :string,
            readline: :get_files,
            walkthru_na: :ssvc_na,
            invalid_msg: 'Invalid Icon. Must exist locally and be a PNG, JPG, or GIF file.',
            desc: <<~ENDDESC
              Path to a local image file to use as the icon for this title in Self Service.
              The file must be a PNG, JPG, or GIF file. The recommended size is 512x512 pixels.
              If one has already been set, this will replace it.
            ENDDESC
          },

          # @!attribute created_by
          #   @return [String] The login of the admin who created this title
          created_by: {
            label: 'Created By',
            type: :string,
            cli: false,
            read_only: true, # maintained by the server, not editable by xadm TODO: same as cli: false??
            desc: <<~ENDDESC
              The login of the admin who created this title.
            ENDDESC
          },

          # @!attribute creation_date
          #   @return [Time] The date this title was created.
          creation_date: {
            label: 'Creation Date',
            type: :time,
            cli: false,
            read_only: true, # maintained by the server, not editable by xadm
            desc: <<~ENDDESC
              The date this title was created.
            ENDDESC
          },

          # @!attribute modified_by
          #   @return [String] The login of the admin who last modified this title
          modified_by: {
            label: 'Modified By',
            type: :string,
            cli: false,
            read_only: true, # maintained by the server, not editable by xadm
            desc: <<~ENDDESC
              The login of the admin who last modified this title.
            ENDDESC
          },

          # @!attribute modification_date
          #   @return [Time] The date this title was last modified.
          modification_date: {
            label: 'Modification Date',
            type: :time,
            cli: false,
            read_only: true, # maintained by the server, not editable by xadm
            desc: <<~ENDDESC
              The date this title was last modified.
            ENDDESC
          }

        }.freeze

        ATTRIBUTES.each_key do |attr|
          attr_accessor attr
        end

        # Constructor
        ######################
        ######################

        # Instance Methods
        ######################
        ######################

      end # class Title

    end # module BaseClasses

  end # module Core

end # module Xolo
