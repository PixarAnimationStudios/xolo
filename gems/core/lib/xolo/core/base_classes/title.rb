# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#
#

# frozen_string_literal: true

# main module
module Xolo

  module Core

    module BaseClasses

      # The base class for dealing with Titles in the
      # Xolo Server, Admin, and Client modules.
      #
      # This class holds the common aspects of Xolo Titles as used
      # on the Xolo server, in the Xolo Admin CLI app 'xadm', and the
      # client app 'xolo' - most importately it defines which data they
      # exchange.
      #
      ############################
      class Title < Xolo::Core::BaseClasses::ServerObject

        # Mixins
        #############################
        #############################

        # Constants
        #############################
        #############################

        MIN_TITLE_DESC_LENGTH = 25

        # Attributes
        ######################
        ######################

        # Attributes of Titles.
        #
        # This hash defines the common attributes of all Xolo titles - which should
        # be available in all subclasses, both on the server, in xadm, and via the
        # client.
        #
        # Each of those subclasses might define (and store or calculate) other
        # attributes as needed.
        #
        # Importantly, the attributes defined here are those that are transfered
        # between xadm and the server as JSON data, and then used to instantiate the
        # title in the local context. They are also stored in the JSON file deployed
        # to clients containing all currently known titles and versions.
        #
        # In this hash, each key is the name of an attribute, and the values are
        # hashes defining the details of that attribute.
        #
        # Since they are used by all subclasses, the details may include info used
        # by one subclass but not another. For example, these attributes are
        # used to create/define CLI & walkthru options for xadm, the settings for
        # which are ignored on the server.
        #
        # The info below also applies to {Xolo:Core::BaseClasses::Version::ATTRIBUTES}, q.v.
        #
        # Title attributes have these details:
        #
        # - label: [String] to be displayed in admin interaction, walkthru, help msgs
        #    or error messages. e.g. 'Display Name' for the attribute display_name
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
        #   If this attribute can't be set via walkthru or a CLI option, set this to false.
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
        #   - If true (not just truthy) call method named 'validate_<key>' in {Xolo::Admin::Validate}
        #     passing in the value to validate.
        #     e.g. Xolo::Admin::Validate.validate_display_name(new_display_name)
        #
        #   - If a Symbol, it's an arbitrary method to call on the {Xolo::Admin::Validate} module
        #     e.g. :non_empty_array will validate the value using
        #     Xolo::Admin::Validate.non_empty_array(some_array_value)
        #
        #   - Anything else: no validation, and the value will be a String
        #
        # - type: [Symbol] the data type of the value. One of: :boolean, :string, :integer,
        #   :time
        #
        #   NOTE: We are not using Optimist's validation & auto-conversion of these types, they
        #   all come from the CLI as strings, and the matching method in {Xolo::Admin::Validate}
        #   is used to validate and convert the values.
        #   The YARD docs for each attribute indicate the Class of the value in the
        #   Title object after CLI processing.
        #
        # - invalid_msg: [String] Custom message to display when the value fails validation.
        #
        # - desc: [String] Helpful text explaining what the attribute is, and what its CLI option means.
        #   Displayed during walkthru, in help messages, and in some err messages.
        #
        # - walkthru_na: [Symbol] The name of a method to call (usually defined in
        #   {Xolo::Admin::Interactive}) when building the walk thru menu item for this option.
        #   If it returns a string, it is an explanation of wny this option
        #   is not available at the moment, and the item is not selectable. If it returns nil, the
        #   item is displayed and handled as normal.
        #
        # - multiline [Boolean] If true, the value for this option can be many lines lione, and in
        #   walkthru, will be presented to the user in an editor like vim. See also multi: above
        #
        # - ted_attribute: [Symbol] If this attribute has a matching one on the related
        #   Title Editor Title, this is the name of that attribute in the Windoo::SoftwareTitle
        #
        # - readline: [Symbol] If set, use readline to get the value from the user during walkthru.
        #   If the symbol is :get_files, a custom method is called that  uses readline with shell-style
        #   auto-complete to get one or more file paths.
        #   Any other symbol is the name of a method to call, which will return an array of possible
        #   values for the option, which will be used for readline-based auto-completion.
        #
        # - readline_prompt: When using readline to gather mulit: values, this prompt is shown at the
        #   start of each line of input for the next item.
        #
        # - read_only: [Boolean] defaults to false. When true, the server maintains this value, and
        #   its only readable via xadm.
        #
        # - hide_from_info: [Boolean] when true, do not show this attribute in the 'info' xadm output
        #   NOTE: it will still be available when --json is given with the info command.
        #
        # - changelog: [Boolean] When true, changes to this attribute is included in the changelog for the title.
        #
        ATTRIBUTES = {

          # @!attribute title
          #   @return [String] The unique title-string for this title.
          title: {
            label: 'Title',
            ted_attribute: :id,
            required: true,
            immutable: true,
            cli: false,
            type: :string,
            hide_from_info: true,
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
            ted_attribute: :name,
            required: true,
            cli: :n,
            type: :string,
            validate: :validate_title_display_name,
            invalid_msg: 'Not a valid display name, must be at least three characters long.',
            changelog: true,
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
            changelog: true,
            multiline: true,
            invalid_msg: <<~ENDINV,
              Not a valid description, must be at least #{MIN_TITLE_DESC_LENGTH} characters.

              Provide a useful dscription of what the software does, URLs, developer names, etc.

              DO NOT USE, e.g. 'Installs Some App', because we know that already and it isn't helpful.
            ENDINV
            desc: <<~ENDDESC
              A useful dscription of what the software installed by this title does. You can also include URLs, developer names, support info, etc.

              DO NOT use, e.g. 'Installs Some App', because we know that already and it isn't helpful.

              IMPORTANT: If this title appears in Self Service, the description will be visible to users.

              Must be at least #{MIN_TITLE_DESC_LENGTH} Characters.
            ENDDESC
          },

          # @!attribute publisher
          #   @return [String] The entity that publishes this title
          publisher: {
            label: 'Publisher',
            ted_attribute: :publisher,
            required: true,
            cli: :P,
            type: :string,
            validate: true,
            changelog: true,
            invalid_msg: '"Not a valid Publisher, must be at least three characters.',
            desc: <<~ENDDESC
              The company or entity that publishes this title, e.g. 'Apple, Inc.' or 'Pixar Animation Studios'.
            ENDDESC
          },

          # @!attribute app_name
          #   @return [String] The name of the .app installed by this title. Nil if no .app is installed
          app_name: {
            label: 'App Name',
            ted_attribute: :appName,
            cli: :a,
            validate: true,
            type: :string,
            changelog: true,
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
            ted_attribute: :bundleId,
            cli: :b,
            validate: true,
            type: :string,
            changelog: true,
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
            # while the script is stored in the Title Editor as the extension attribute
            # its handled differently, so we don't specify a ted_attribute here.
            validate: true,
            type: :string,
            readline: :get_files,
            changelog: true,
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

          # Whenever one of the groups listed is Xolo::TARGET_ALL ('all') then all other groups are
          # ignored or deleted and the array contains only 'all'
          #
          # @!attribute release_groups
          #   @return [Array<String>] Jamf groups that will automatically get this title installed or
          #     updated when released
          release_groups: {
            label: 'Release Computer Groups',
            cli: :r,
            validate: true,
            type: :string,
            multi: true,
            readline_prompt: 'Group Name',
            changelog: true,
            readline: :jamf_computer_group_names,
            invalid_msg: 'Invalid release group(s). Must exist in Jamf and not be excluded.',
            desc: <<~ENDDESC
              One or more Jamf Computer Groups whose members will automatically have this title installed when new versions are released.

              If your Xolo administrators allow it, you can use '#{Xolo::TARGET_ALL}' to auto-install on all computers that aren't excluded. If not, you'll be told how to request setting release groups to '#{Xolo::TARGET_ALL}'.

              NOTE: Titles can always be installed manually (via command line or Self Service) on non-excluded computers. It's OK to have no release groups.

              When using the --release-groups CLI option, you can specify more than one group by using the option more than once, or by providing a single option value with the groups separated by commas.

              To remove all existing, use '#{Xolo::NONE}'.

              NOTE: When a version is in 'pilot', before it is released, these groups are ignored, but instead a set of 'pilot' groups is defined for each version - and those groups will have that version auto-installed.
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
            changelog: true,
            readline_prompt: 'Group Name',
            readline: :jamf_computer_group_names,
            invalid_msg: 'Invalid excluded computer group(s). Must exist in Jamf.',
            desc: <<~ENDDESC
              One or more Jamf Computer Groups whose members are not allowed to install this title.

              When a computer is in one of these groups, the title is not available even if the computer is in a pilot or release group.

              When using the --excluded-groups CLI option, you can specify more than one group by using the option more than once, or by providing a single option value with the groups separated by commas.

              To remove all existing, use '#{Xolo::NONE}'.

              NOTE: Regardless of the excluded groups set here, if the server has defined a 'forced_exclusion' in its config, that group is always excluded from all xolo titles. Also, computers that are 'frozen' for a title are excluded.
            ENDDESC
          },

          # @!attribute uninstall_script
          #   @return [String] The path to a script starting with '#!' that will uninstall any version of
          #     this title.
          uninstall_script: {
            label: 'Uninstall Script',
            cli: :U,
            validate: true,
            type: :string,
            readline: :get_files,
            walkthru_na: :uninstall_script_na,
            changelog: true,
            invalid_msg: "Invalid Script Path. Local File must exist and start with '#!'.",
            desc: <<~ENDDESC
              By default, Xolo cannot un-install a title. To make it do so you must provide either --uninstall-script or --uninstall-ids.

              When using --uninstall-script, provide a path to a local file containing a script (starting with '#!') that will uninstall any version of this title.

              This is useful when the publisher provides a custom uninstaller, or to uninstall things that were not installed via .pkg files (e.g. drag-installs).

              Either --uninstall-script or --uninstall-ids must be provided if you want to set --expiration.

              Use '#{Xolo::NONE}' to unset this,
            ENDDESC
          },

          # @!attribute uninstall_ids
          #   @return [String] One or more package identifiers recognized by pkgutil, that will uninstall the
          #     currently installed version of if this title.
          uninstall_ids: {
            label: 'Uninstall IDs',
            cli: :u,
            validate: true,
            type: :string,
            multi: true,
            multi_prompt: 'Pkg ID',
            walkthru_na: :uninstall_ids_na,
            changelog: true,
            invalid_msg: 'Invalid uninstall ids',
            desc: <<~ENDDESC
              By default, Xolo cannot un-install a title. To make it do so you must provide either --uninstall-ids or --uninstall-script.

              When using --uninstall-ids, provide one or more package identifiers, as listed by `pkgutil --pkgs`.
              Xolo will use them to create a Jamf Script that will delete all the files that were installed by the matching .pkg installers.

              NOTE: Package IDs will not work if the item was installed without using an installer.pkg
              (e.g. drag-installing)

              Either --uninstall-script or --uninstall-ids must be provided if you want to set --expiration.

              When using the --uninstall-ids CLI option, you can specify more than one ID by using the option more than once, or by providing a single option value with the IDs separated by commas.

              Use '#{Xolo::NONE}' to unset this,
            ENDDESC
          },

          # @!attribute expiration
          #   @return [Integer] Number of days of disuse before the title is uninstalled.
          expiration: {
            label: 'Expire Days',
            cli: :e,
            validate: true,
            type: :integer,
            walkthru_na: :expiration_na,
            changelog: true,
            invalid_msg: "Invalid expiration. Must be a non-negative integer, or zero or '#{Xolo::NONE}' for no expiration.",
            desc: <<~ENDDESC
              Automatically uninstall this title if none of the items listed as '--expire-paths' have been opened in this number of days.
              This can be useful for reclaiming unused licenses, especially if users can re-install as needed via Self Service.

              IMPORTANT:
              - This title must have an '--uninstall-method' set, or it can't be uninstalled by xolo
              - You must define one or more --expire-paths

              Setting this to '#{Xolo::NONE}' or zero, means 'do not expire'.
            ENDDESC
          },

          # @!attribute expire_paths
          #   @return [Array<String>] App names that are considered to be 'used' if they spend any time
          #      in the foreground.
          expire_paths: {
            label: 'Expiration Paths',
            cli: :E,
            validate: true,
            type: :string,
            multi: true,
            walkthru_na: :expiration_paths_na,
            changelog: true,
            readline: :get_files,
            readline_prompt: 'Path',
            invalid_msg: 'Invalid expiration paths. Must be absolute paths starting with /',
            desc: <<~ENDDESC
              The full paths to one or items (e.g. '/Applications/Google Chrome.app') that must be opened within the --expiration period to prevent automatic uninstall of the title. The paths need not be .apps, but can be anything. If the item at the path has never been opened, its date-added is used. If it doesn't exist, it is considered to never have been opened.

              If multiple paths are specified, any one of them being opened will count. This is useful for multi-app titles, such as Microsoft Office, or when different versions have different app names.

              When using the --expiration-paths CLI option, you can specify more than one path by using the option more than once, or by providing a single option value with the paths separated by commas.
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
            changelog: true,
            walkthru_na: :ssvc_na,
            desc: <<~ENDDESC
              Make this title available in Self Service. Only the currently released version will be available.

              While in pilot, a version is installed via its auto-install policy,
              or 'sudo xolo install <title> <version>' or updated via its Patch Policy.

              It will never be available to excluded computers.

              Self Service is not available for titles with the release_group 'all'.
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
            changelog: true,
            readline: :jamf_category_names,
            invalid_msg: 'Invalid category. Must exist in Jamf Pro.',
            desc: <<~ENDDESC
              The Category in which to display this title in Self Service.
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
            changelog: true,
            walkthru_na: :ssvc_na,
            invalid_msg: 'Invalid Icon. Must exist locally and be a PNG, JPG, or GIF file.',
            desc: <<~ENDDESC
              Path to a local image file to use as the icon for this title in Self Service.
              The file must be a PNG, JPG, or GIF file. The recommended size is 512x512 pixels.
              If one has already been set, this will replace it.
            ENDDESC
          },

          # @!attribute contact_email
          #   @return [String] Email address for the person or team responsible for this title
          contact_email: {
            label: 'Contact Email Address',
            cli: :m,
            required: true,
            validate: true,
            type: :string,
            changelog: true,
            invalid_msg: 'Invalid Email address.',
            desc: <<~ENDDESC
              The email address of the team or person responsible for this title. Used for notifications, questions, etc.

              A mailing list for a team is preferable to an individual's email address, since individuals may leave the team.
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
          },

          # @!attribute version_order
          #   @return [Array<String>] The known versions, newest to oldest
          version_order: {
            label: 'Versions',
            type: :string,
            multi: true,
            cli: false,
            read_only: true, # maintained by the server, not editable by xadm
            desc: <<~ENDDESC
              The known versions of the title, newest to oldest
            ENDDESC
          },

          # @!attribute released_version
          #   @return [String] The currently released version, if any
          released_version: {
            label: 'Released Version',
            type: :string,
            cli: false,
            changelog: true,
            read_only: true, # maintained by the server, not editable by xadm
            desc: <<~ENDDESC
              The currently released version
            ENDDESC
          }

        }.freeze

        ATTRIBUTES.each_key do |attr|
          attr_accessor attr
        end

        # Constructor
        ######################
        ######################

        def initialize(data_hash)
          super
          # zero means no expiration
          @expiration = nil if @expiration.to_i.zero?
        end

        # Instance Methods
        ######################
        ######################

        # the latest version of this title in Xolo
        # @param cnx [Faraday::Connection] The connection to use, must be logged in already
        # @return [String]
        ####################
        def latest_version
          version_order&.first
        end

      end # class Title

    end # module BaseClasses

  end # module Core

end # module Xolo
