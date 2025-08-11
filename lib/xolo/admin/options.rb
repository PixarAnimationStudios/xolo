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

# frozen_string_literal: true

module Xolo

  module Admin

    # A module for defining the CLI and Interactive options for xadm.
    #
    # The general structure of xadm commands is:
    #   xadm [global options] command [command options] [command arguments]
    # in that order.
    #
    # The global options are things that affect the overall behavior of xadm,
    # like --walkthru, --quiet, --json, and --debug.
    #
    # The command is the action to be taken, like 'add-title', 'edit-version',
    # 'list-titles', etc.
    #
    # The command options are specific to the command, and are defined in the
    # COMMANDS hash below.
    #
    # The command arguments are the things the command operates on, like the
    # title name, or the title name and version.
    #
    module Options

      # Constants
      #########################
      #########################

      # These options affect the overall behavior of xadm. They must come
      # before the command.
      #
      # NOTE: Optimist automatically provides --version -v and --help -h
      GLOBAL_OPTIONS = {
        walkthru: {
          label: 'Run Interactively',
          walkthru: false,
          cli: :w,
          desc: <<~ENDDESC
            Run xadm in interactive mode when adding or editing titles or versions.
            This causes xadm to present an interactive, menu-and-
            prompt-driven interface. All command-options given on the
            command line are ignored, and will be gathered
            interactively.
            The 'config' command is always interactive, even without --walkthru.
          ENDDESC
        },

        auto_confirm: {
          label: 'Auto Approve',
          cli: :a,
          walkthru: false,
          desc: <<~ENDDESC
            Do not ask for confirmation before making changes or using server-
            admin commands.
            This is mostly used for automating xadm.
            Ignored if using --walkthru: if you're interactive you must confirm
            your changes.
            WARNING: Be careful that all values are correct.
          ENDDESC
        },

        proxy_admin: {
          label: 'Proxy Admin',
          cli: :p,
          walkthru: false,
          type: :string,
          validate: false,
          desc: <<~ENDDESC
            Used for automated workflows that connect to the xolo server using a
            service account, not a user account. Most such automations have a way to
            ascertain the identity of the user triggering the automation. They can use
            that name here, and then it will be used on the server combined with the
            actually authenticated service acct name for use in logging and status.

            For example, if you have a CI/CD job that runs xadm commands, it will
            connect to the xolo server using a service account such as 'xolo-cicd-runner'.
            That job can get the name of the user triggering the job from an environment
            variable, (or elsewhere) and pass that as the value of this option, like so:

              xadm --proxy-admin $CICD_USER_NAME add-version my-title 1.2.3 [options...]

            On the xolo server, the user will be recorded as

              cicduser-via-xolo-cicd-runner

            which will be used as the "added_by" value for the new version, and will show up
            in the various logs.
          ENDDESC
        },

        quiet: {
          label: 'Quiet',
          cli: :q,
          walkthru: false,
          desc: <<~ENDDESC
            Run xadm in quiet mode
            When used with add-, edit-, delete-, and release-
            commands, nothing will be printed to standard output.

            Ignored for other commands, the purpose of which is to print
            something to standard output.
            Also ignored if --debug is given

            WARNING: For long-running processes, you may not see server errors!
          ENDDESC
        },

        json: {
          label: 'JSON',
          cli: :j,
          walkthru: false,
          desc: <<~ENDDESC
            For commands that output lists or info about titles and versions,
            such as 'list-titles' or 'info <title> <version>',
            return the data as raw JSON.
          ENDDESC
        },

        debug: {
          label: 'Debug',
          cli: :d,
          walkthru: false,
          desc: <<~ENDDESC
            Run xadm in debug mode
            This causes more verbose output and full backtraces
            to be printed on errors. Overrides --quiet
          ENDDESC
        }
      }.freeze

      # The xadm commands
      #############################

      # TODO: add commands for:
      # - upload a manifest for a version
      # - get the status of an MDM command given a uuid
      # - get the code of a version script
      # - get the code of an uninstall script
      # - output the contents of a previous progress stream file, if it still exists

      LIST_TITLES_CMD = 'list-titles'
      ADD_TITLE_CMD = 'add-title'
      EDIT_TITLE_CMD = 'edit-title'
      DELETE_TITLE_CMD = 'delete-title'
      FREEZE_TITLE_CMD = 'freeze'
      THAW_TITLE_CMD = 'thaw'
      LIST_FROZEN_CMD = 'list-frozen'

      LIST_VERSIONS_CMD = 'list-versions'
      ADD_VERSION_CMD = 'add-version'
      EDIT_VERSION_CMD = 'edit-version'
      RELEASE_VERSION_CMD = 'release'
      DELETE_VERSION_CMD = 'delete-version'
      DEPLOY_VERSION_CMD = 'deploy'

      INFO_CMD = 'info' # info on a title or version
      SEARCH_CMD = 'search' # search for titles
      CHANGELOG_CMD = 'changelog' # show the changelog for a title
      REPORT_CMD = 'report' # report on installations
      CONFIG_CMD = 'config' # configure xadm

      LIST_GROUPS_CMD = 'list-groups'
      LIST_CATEGORIES_CMD = 'list-categories'

      SERVER_STATUS_CMD = 'server-status'
      HELP_CMD = 'help'

      # server-admin commands
      SERVER_CLEANUP_CMD = 'run-server-cleanup'
      UPDATE_CLIENT_DATA_CMD = 'update-client-data'
      ROTATE_SERVER_LOGS_CMD = 'rotate-server-logs'
      SET_SERVER_LOG_LEVEL_CMD = 'set-server-log-level'
      SHUTDOWN_SERVER_CMD = 'shutdown-server'

      # various strings for the commands and opts

      HELP_OPT = '--help'

      DFT_CMD_TITLE_ARG_BANNER = "  title:     The unique name of a title in Xolo, e.g. 'google-chrome'"
      DFT_CMD_VERSION_ARG_BANNER = "  version:   The version of the title you are working with. e.g. '12.34.5'"

      TARGET_TITLE_PLACEHOLDER = 'TARGET_TITLE_PH'
      TARGET_VERSION_PLACEHOLDER = 'TARGET_VERSION_PH'

      PATCH_REPORT_OPTS = {
        summary: {
          label: 'Summary Only',
          cli: :S,
          type: :boolean,
          validate: :validate_boolean,
          default: false,
          desc: <<~ENDDESC
            Show a summary only: how many installs of each version, and how many in total.
          ENDDESC
        },

        os: {
          label: 'Show Operating System Version',
          cli: :o,
          type: :boolean,
          validate: :validate_boolean,
          default: false,
          desc: <<~ENDDESC
            Report the Operating System Version of the computer.
          ENDDESC
        },

        building: {
          label: 'Show Building',
          cli: :b,
          type: :boolean,
          validate: :validate_boolean,
          default: false,
          desc: <<~ENDDESC
            Report the Building of the computer.
          ENDDESC
        },

        dept: {
          label: 'Show Department',
          cli: :d,
          type: :boolean,
          validate: :validate_boolean,
          default: false,
          desc: <<~ENDDESC
            Report the Department of the computer.
          ENDDESC
        },

        site: {
          label: 'Show Site',
          cli: :s,
          type: :boolean,
          validate: :validate_boolean,
          default: false,
          desc: <<~ENDDESC
            Report the Site of the computer.
          ENDDESC
        },

        frozen: {
          label: 'Show Frozen Status',
          cli: :f,
          type: :boolean,
          validate: :validate_boolean,
          default: false,
          desc: <<~ENDDESC
            Report whether or not the computer is frozen for the title.
          ENDDESC
        },

        id: {
          label: 'Show Jamf ID',
          cli: :i,
          type: :boolean,
          validate: :validate_boolean,
          default: false,
          desc: <<~ENDDESC
            Report the Jamf ID of the computer.
          ENDDESC
        }
      }.freeze

      FREEZE_THAW_OPTIONS = {
        users: {
          label: 'Targets are usernames not computers',
          cli: :u,
          type: :boolean,
          validate: :validate_boolean,
          default: false,
          desc: <<~ENDDESC
            The targets of the command are usernames, not computers. All computers assigned to the user will be affected.
            Default is false, targets are computer names.
          ENDDESC
        }
      }.freeze

      DEPLOY_VERSION_OPTIONS = {
        groups: {
          label: 'Computer group whose computers will be targeted',
          cli: :g,
          validate: :validate_deploy_groups,
          type: :string,
          multi: true,
          readline_prompt: 'Group Name',
          readline: :jamf_computer_group_names,
          desc: <<~ENDDESC
            One or more Jamf Computer Group names or ids whose members will receive the MDM deployment.

            When using the --groups CLI option, you can specify more than one group by using the option more than once, or by providing a single option value with the groups separated by commas.
          ENDDESC
        }
      }.freeze

      SERVER_STATUS_OPTIONS = {
        extended: {
          label: 'Show Extended Status',
          cli: :e,
          type: :boolean,
          validate: :validate_boolean,
          default: false,
          desc: <<~ENDDESC
            Include more status information about the server, including the current
            GEM_PATH, $LOAD_PATH, current object locks, and existing threads.
          ENDDESC
        }
      }.freeze

      # The commands that xadm understands
      # For each command there is a hash of details, with these possible keys:
      #
      # - desc: [String] a one-line description of the command
      #
      # - display: [String] The command with any arguments, but no options.
      #   If no more specific usage: is defined, this is used in the help output
      #   to build the 'usage' line: "#{executable_file} #{cmd_display} [options]"
      #
      # - usage: [String] If the usage line generated with the display: value is inaccurate,
      #   you can define one explicitly here to override it.
      #
      # - arg_banner: [String] a line of help text defining the arguments taken by the command.
      #   Defaults to Xolo::Admin::Options::DFT_CMD_TITLE_ARG_BANNER
      #   Will automatically append Xolo::Admin::Options::DFT_CMD_VERSION_ARG_BANNER if
      #   the command is a version command. If ths command takes no args, set this to :none
      #
      # - target: [Symbol] Most commands operate on either titles, versions, or both. Set this
      #   to one of :title, :version, or :title_or_version to let xadm apply revelant state.
      #   Leave unset if the command doesn't take anything
      #
      # - confirmation: [Boolean] does this action require confirmation? (Are you sure?)
      #   Confirmation can be overriden with the --auto-confirm global opt, as is needed
      #   for using xadm in an automated workflow
      #
      # - opts: [Hash] The keys and details about all the options that can be given to this
      #   command. It is usually a constant from some other part of Xolo::Admin.
      #   See {Xolo::Core::BaseClasses::Title::ATTRIBUTES} for info about the contents
      #   of this Hash. If the command takes no options, set this to an empty hash '{}'
      #
      # - walkthru_header: A string displayed above the main walkthru menu describing what
      #   is happening. E.g. 'Editing Title foobar'.
      #   Use TARGET_TITLE_PLACEHOLDER and TARGET_VERSION_PLACEHOLDER as needed to sub in the
      #   names of the targets.
      #
      # - no_login: [Boolean] By default, xadm will connect to the xolo server. If that isn't
      #   needed for this command, set this to true.
      #
      # - process_method: [Symbol] The name of a method defined in Xolo::Admin::Processing.
      #   This method will be called to do the actual work of the command, after processing all
      #   the arguments and options.
      #
      # - streamed_response: [Boolean] Used for long-running server processes, like delete_title
      #   or delete_version. When true, we don't expect a final JSON response from the server, but
      #   instead a link to a stream of status messages, which we just print out as they arrive.
      #
      ###### Arguments vs options:
      #
      # We're using a more formal definition of these terms here.
      #
      # An argument is a value taken by a command - the thing the command will
      # operate upon. This is usually a title, or a title and a version.
      #
      # An option is something that defines or modifies what the command will do
      # with the argument(s). Options always begin with '-' or '--'
      #
      COMMANDS = {

        LIST_TITLES_CMD => {
          desc: 'List all software titles.',
          display: LIST_TITLES_CMD,
          opts: {},
          arg_banner: :none,
          process_method: :list_titles,
          target: :none
        },

        ADD_TITLE_CMD => {
          desc: 'Add a new software title',
          display: "#{ADD_TITLE_CMD} title",
          opts: Xolo::Admin::Title.cli_opts,
          walkthru_header: "Adding Xolo Title '#{TARGET_TITLE_PLACEHOLDER}'",
          target: :title,
          process_method: :add_title,
          streamed_response: true,
          confirmation: true
        },

        EDIT_TITLE_CMD => {
          desc: 'Edit an exising software title',
          display: "#{EDIT_TITLE_CMD} title",
          opts: Xolo::Admin::Title.cli_opts,
          walkthru_header: "Editing Xolo Title '#{TARGET_TITLE_PLACEHOLDER}'",
          process_method: :edit_title,
          target: :title,
          streamed_response: true,
          confirmation: true
        },

        DELETE_TITLE_CMD => {
          desc: 'Delete a software title, and all of its versions',
          display: "#{DELETE_TITLE_CMD} title",
          opts: {},
          process_method: :delete_title,
          target: :title,
          streamed_response: true,
          confirmation: true
        },

        FREEZE_TITLE_CMD => {
          desc: 'Prevent computers from updating the currently installed version of a title.',
          long_desc: <<~ENDLONG,
            The target computers are added to a static group that is excluded from
            all policies and patch policies related to this title and its versions.
            If a computer doesn't have any version of the title, this will prevent
            it from being installed via xolo (it will be 'frozen' in that state).
          ENDLONG
          display: "#{FREEZE_TITLE_CMD} title [--users] target [target ...] ",
          opts: FREEZE_THAW_OPTIONS,
          process_method: :freeze,
          target: :title,
          confirmation: true
        },

        THAW_TITLE_CMD => {
          desc: 'Un-freeze computers, allowing them to resume updates of a title.',
          ong_desc: <<~ENDLONG,
            The target computers are removed from the static group that is excluded from
            all policies and patch policies related to this title and its versions.
            This will allow installation and updates to resume.
          ENDLONG
          display: "#{THAW_TITLE_CMD} title [--users] target [target ...]",
          opts: FREEZE_THAW_OPTIONS,
          process_method: :thaw,
          target: :title,
          confirmation: true
        },

        LIST_FROZEN_CMD => {
          desc: 'List all computers that are frozen for a title.',
          display: "#{LIST_FROZEN_CMD} title",
          opts: {},
          target: :title,
          process_method: :list_frozen
        },

        LIST_VERSIONS_CMD => {
          desc: 'List all versions of a title.',
          display: "#{LIST_VERSIONS_CMD} title",
          opts: {},
          target: :title,
          process_method: :list_versions
        },

        ADD_VERSION_CMD => {
          desc: 'Add a new version to a title, making it available for piloting',
          display: "#{ADD_VERSION_CMD} title version",
          long_desc: <<~ENDLONG,
            The version will be automatically installed or updated on any computers
            in the 'pilot-groups' defined for the version. To manually install it
            on other computers, you must use 'xolo install <title> <version>'.
          ENDLONG
          opts: Xolo::Admin::Version.cli_opts,
          walkthru_header: "Adding Version '#{TARGET_VERSION_PLACEHOLDER}' to Xolo Title '#{TARGET_TITLE_PLACEHOLDER}'",
          process_method: :add_version,
          target: :version,
          streamed_response: true,
          confirmation: true
        },

        EDIT_VERSION_CMD => {
          desc: 'Edit a version of a title',
          display: "#{EDIT_VERSION_CMD} title version",
          opts: Xolo::Admin::Version.cli_opts,
          walkthru_header: "Editing Version '#{TARGET_VERSION_PLACEHOLDER}' of Xolo Title '#{TARGET_TITLE_PLACEHOLDER}'",
          target: :version,
          process_method: :edit_version,
          streamed_response: true,
          confirmation: true
        },

        RELEASE_VERSION_CMD => {
          desc: "Take a version out of pilot and make it 'live'.",
          long_desc: <<~ENDLONG,
            Once released, the version will be updated on all computers
            where it is installed. It will also be the version installed
            manually on a computer when running 'xolo install <title>'.
          ENDLONG
          display: "#{RELEASE_VERSION_CMD} title version",
          opts: {},
          target: :version,
          process_method: :release_version,
          streamed_response: true,
          confirmation: true
        },

        DELETE_VERSION_CMD => {
          desc: 'Delete a version from a title.',
          display: "#{DELETE_VERSION_CMD} title version",
          opts: {},
          target: :version,
          process_method: :delete_version,
          streamed_response: true,
          confirmation: true
        },

        # TODO: allow uploading of manifests for xolo versions, to be used
        # instead of the one generated by the server.
        DEPLOY_VERSION_CMD => {
          desc: 'Use MDM to deploy a version of a title on one or more computers or computer groups.',
          long_desc: <<~ENDLONG,
            An MDM 'InstallEnterpriseApplication' command will be sent to the target computers to
            install the version. If the version is already installed, it will be updated.
            Computers in any excluded-groups for the target will be removed from the list of targets
            before the MDM command is sent.

            Computers can be specified by name, serial number, or Jamf ID. Groups can be specified by
            name or ID.

            The package for the version must be a signed 'Product Archive', like those built with
            'productbuild', not a 'component package', as is generated by 'pkgbuild'.
            When you upload the .pkg to Xolo, it will automatically get a basic manifest needed for
            the MDM command.
          ENDLONG
          display: "#{DEPLOY_VERSION_CMD} title version [computer ...]",
          opts: DEPLOY_VERSION_OPTIONS,
          target: :version,
          process_method: :deploy_version,
          confirmation: true
        },

        SEARCH_CMD => {
          desc: 'Search for titles.',
          long_desc: <<~ENDLONG,
            Matches text in title, display name, publisher, app name, bundle ID,
            or description.
          ENDLONG
          display: "#{SEARCH_CMD} title",
          opts: {},
          target: :title,
          process_method: :search_titles
        },

        INFO_CMD => {
          desc: 'Show details about a title, or a version of a title',
          display: "#{INFO_CMD} title [version]",
          opts: {},
          target: :title_or_version,
          process_method: :show_info
        },

        REPORT_CMD => {
          desc: 'Show a patch-report for a title, or a version of a title',
          long_desc: <<~ENDDESC,
            Patch reports list which computers have a title, or a version of the title, installed.
            They always show the computer name, username and last contact date. If reporting all
            versions, the version on each computer will also be listed.

            Commandline options can be used to add more data to the report, such as operating system,
            department, site, and so on.

            To see machines with an unknown version of a title, use '#{Xolo::UNKNOWN}' as the version.

            NOTE: When using --json, all options are included in the data.
          ENDDESC
          display: "#{REPORT_CMD} title [version]",
          opts: PATCH_REPORT_OPTS,
          target: :title_or_version,
          process_method: :patch_report
        },

        CHANGELOG_CMD => {
          desc: 'Show the changelog for a title',
          long_desc: <<~ENDDESC,
            The changelog is a list of all the changes made to the title and its versions.
          ENDDESC
          display: "#{CHANGELOG_CMD} title",
          opts: {},
          target: :title,
          process_method: :show_changelog
        },

        CONFIG_CMD => {
          desc: 'Configure xadm. Always interactive, implies --walkthru',
          display: CONFIG_CMD,
          usage: "#{Xolo::Admin::EXECUTABLE_FILENAME} #{CONFIG_CMD}",
          opts: Xolo::Admin::Configuration.cli_opts,
          walkthru_header: 'Editing xadm configuration',
          no_login: true,
          arg_banner: :none,
          process_method: :update_config
        },

        LIST_GROUPS_CMD => {
          desc: 'List all computer groups in Jamf pro',
          display: "#{LIST_GROUPS_CMD}",
          usage: "#{Xolo::Admin::EXECUTABLE_FILENAME} #{LIST_GROUPS_CMD}",
          opts: {},
          arg_banner: :none,
          process_method: :list_groups
        },

        LIST_CATEGORIES_CMD => {
          desc: 'List all categories in Jamf pro',
          display: "#{LIST_CATEGORIES_CMD}",
          usage: "#{Xolo::Admin::EXECUTABLE_FILENAME} #{LIST_CATEGORIES_CMD}",
          opts: {},
          arg_banner: :none,
          process_method: :list_categories
        },

        HELP_CMD => {
          desc: 'Get help for a specifc command',
          display: 'help command',
          opts: {},
          no_login: true
        },

        SERVER_STATUS_CMD => {
          desc: 'Show status of Xolo server.',
          long_desc: <<~ENDLONG,
            Requires server-admin privileges.
            Displays the current status of the server, including uptime, log level,
            versions of various libraries, configuration, more.
          ENDLONG
          display: SERVER_STATUS_CMD,
          opts: SERVER_STATUS_OPTIONS,
          arg_banner: :none,
          process_method: :server_status
        },

        SERVER_CLEANUP_CMD => {
          desc: "Run the server's cleanup process now.",
          long_desc: <<~ENDLONG,
            Requires server-admin privileges.
            Once a version of a title is released, the preveiously released
            version is marked as 'deprecated', and any older unreleased versions
            are marked as 'skipped'. A nightly task will then delete all skipped
            versions from xolo, as well as deprecated versions that have been than
            deprecated more than some number of days, as configured configured on
            the server. Running this command will do that cleanup now.
          ENDLONG
          display: SERVER_CLEANUP_CMD,
          opts: {},
          arg_banner: :none,
          process_method: :server_cleanup,
          confirmation: true
        },

        UPDATE_CLIENT_DATA_CMD => {
          desc: 'Make the server update the client-data package now.',
          long_desc: <<~ENDLONG,
            Requires server-admin privileges.
            Every time a change is made to a title or version, the server updates
            a JSON file with the current state of all titles and versions. This
            file is then packaged and deployed to all managed clients. Running
            this command will force the server to update that file now.
          ENDLONG
          display: UPDATE_CLIENT_DATA_CMD,
          opts: {},
          arg_banner: :none,
          process_method: :update_client_data,
          confirmation: true
        },

        ROTATE_SERVER_LOGS_CMD => {
          desc: 'Rotate the logs on the server now.',
          long_desc: <<~ENDLONG,
            Requires server-admin privileges.
            Server log rotation is normally done nightly. Running this command
            will rotate the logs now.
          ENDLONG
          display: ROTATE_SERVER_LOGS_CMD,
          opts: {},
          arg_banner: :none,
          process_method: :rotate_server_logs,
          confirmation: true
        },

        SET_SERVER_LOG_LEVEL_CMD => {
          desc: 'Set the log level of the server logger.',
          long_desc: <<~ENDLONG,
            Requires server-admin privileges.
            Sets the log level of the server logger to one of 'debug', 'info',
            'warn', 'error', or 'fatal'. This will affect the amount of output
            written to the server log file.
          ENDLONG
          display: SET_SERVER_LOG_LEVEL_CMD,
          usage: "#{Xolo::Admin::EXECUTABLE_FILENAME} #{SET_SERVER_LOG_LEVEL_CMD} level [options]",
          opts: {},
          arg_banner: '  level: The log level to set, one of "debug", "info", "warn", "error", "fatal"',
          process_method: :set_server_log_level,
          confirmation: true
        },

        SHUTDOWN_SERVER_CMD => {
          desc: 'Shutdown or restart the server gracefully.',
          long_desc: <<~ENDLONG,
            Requires server-admin privileges.
            Gracefully stop the xolo server process, optionally restarting it automatically.
            This will attempt to finish any in-progress operations before shutting down.
            If you don't use --restart, you must reload the launchd plist, or reboot the server machine to restart the server process.
          ENDLONG
          display: "#{SHUTDOWN_SERVER_CMD} [--restart]",
          opts: {
            restart: {
              label: 'Restart after shutdown',
              cli: :r,
              type: :boolean,
              validate: :validate_boolean,
              default: false,
              desc: <<~ENDDESC
                Restart the server automatically after shutdown. If not given, you must reload the launchd plist, or reboot the server machine to restart the server process.
              ENDDESC
            }
          },
          arg_banner: :none,
          process_method: :shutdown_server,
          confirmation: true
        }

      }.freeze

      # The commands that add something to xolo - how their options are processed and validated
      # differs from those commands that just edit or report things.
      ADD_COMMANDS = [ADD_TITLE_CMD, ADD_VERSION_CMD].freeze

      EDIT_COMMANDS = [EDIT_TITLE_CMD, EDIT_VERSION_CMD].freeze

      DELETE_COMMANDS = [DELETE_TITLE_CMD, DELETE_VERSION_CMD].freeze

      # For these commands, the title or version must exist
      MUST_EXIST_COMMANDS = [
        EDIT_TITLE_CMD, EDIT_VERSION_CMD,
        DELETE_TITLE_CMD, DELETE_VERSION_CMD, RELEASE_VERSION_CMD,
        FREEZE_TITLE_CMD, THAW_TITLE_CMD, LIST_FROZEN_CMD, CHANGELOG_CMD
      ].freeze

      # Module methods
      ##############################
      ##############################

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # Instance Methods
      ##########################
      ##########################

      # the command definition details from Xolo::Admin::Options::COMMANDS
      #
      # @param cmd [Symbol] A key from Xolo::Admin::Options::COMMANDS
      #   defaults to the current cli_cmd.commadn
      #
      # @return [Hash] The value for the key
      #######################
      def cmd_details(cmd = nil)
        cmd ||= cli_cmd.command
        Xolo::Admin::Options::COMMANDS[cmd]
      end

      # Are we running in interactive mode?
      # --walkthru was givin in the global opts
      # @return [Boolean]
      #######################
      def walkthru?
        global_opts.walkthru
      end

      # are we auto-confirming?
      # --auto-confirm was given in the global opts
      # and we are not using --walkthru
      # @return [Boolean]
      #######################
      def auto_confirm?
        global_opts.auto_confirm && !global_opts.walkthru
      end

      # do we need to ask for confirmation?
      # the command we are running wants confirmation
      # and auto_confirm? is false
      # @return [Boolean]
      #######################
      def need_confirmation?
        cmd_details[:confirmation] && !auto_confirm?
      end

      # are we outputing JSON?
      # @return [Boolean]
      #######################
      def json?
        global_opts.json
      end

      # are we showing debug output?
      # @return [Boolean]
      #######################
      def debug?
        global_opts.debug
      end

      # are we being quiet?
      # --quiet was given, but --debug was not
      # @return [Boolean]
      #######################
      def quiet?
        global_opts.quiet && !debug? && !json?
      end

      # Global Opts
      #
      # The CLI options from xadm that come before the
      # xadm command
      #
      # These are always set by Optimist.
      #
      # See Xolo::Admin::Options.cli_cmd_opts below for
      # a short discussion about the optimist hash.
      #
      # @return [OpenStruct]
      ############################
      def global_opts
        @global_opts ||= OpenStruct.new
      end

      # This will hold 2 or 3 items:
      # :command - the xadm command we are processing
      # :title - the title arg for the xadm command
      # :version - the version arg, if the command processes a version
      #
      # e.g. running `xadm edit-title foobar`
      # - Xolo::Admin::Options.cli_cmd.command => 'edit-title'
      # - Xolo::Admin::Options.cli_cmd.title => 'foobar'
      # - Xolo::Admin::Options.cli_cmd.version => nil
      #
      # e.g. running `xadm edit-version foobar 1.2.34`
      # - Xolo::Admin::Options.cli_cmd.command => 'edit-version'
      # - Xolo::Admin::Options.cli_cmd.title => 'foobar'
      # - Xolo::Admin::Options.cli_cmd.version => '1.2.34'
      #
      # @return [OpenStruct]
      ############################
      def cli_cmd
        @cli_cmd ||= OpenStruct.new
      end

      # CLI Command Opts - the options given on the command line
      # for processing an xadm command.
      #
      # Will be set by Optimist in command_line.rb
      #
      # The options gathered by a walkthru are available in
      # Xolo::Admin::Options.walkthru_cmd_opts
      #
      # The optimist data will contain a key matching every
      # key from the option definitions hash, even if the key
      # wasn't given on the commandline.
      #
      # So if there's a ':foo_bar' option defined, but --foo-bar
      # wasn't given on the commandline,
      # Xolo::Admin::Options.cli_cmd_opts[:foo_bar] will be set, but will
      # be nil.
      #
      # More importantly, for each option that IS given on the commandline
      # the optimist hash will contain a ':opt_name_given' key set to true.
      # so for validation, we can only care about the values for which there
      # is a *_given key, e.g. :foo_bar_given in the example above.
      # See also Xolo::Admin::Validate.cli_cmd_opts.
      #
      # After validating the individual options provided, the values from
      # current_values will be added to cli_cmd_opts for any options not
      # given on the command-line. After that, the whole will be validated
      # for internal consistency.
      #
      # @return [OpenStruct]
      ############################
      def cli_cmd_opts
        @cli_cmd_opts ||= OpenStruct.new
      end

      # Walkthru Command Opts - the options given via walkthrough
      # for processing an xadm command.
      #
      # This is intially set with the default, inherited, or existing
      # values for the object being created or edited.
      #
      # Before the walk through starts, its duped and the dup
      # used as the current_opt_values (see below)
      #
      # In walkthru, the current_opt_values are used to generate the menu
      # items showing the changes being made.
      #
      # e.g. if option :foo (label: 'Foo') starts with value 'bar'
      # at first the menu item will look like:
      #
      #     12) Foo: bar
      #
      # but if the walkthru user changes the value to 'baz', it'll look like this
      #
      #     12) Foo: bar => baz
      #
      # The changes themselves are reflected here in walkthru_cmd_opts, and it will be
      # used for validation of individual options, as well as overall internal
      # consistency, before being applied to the object at hand.
      #
      # @return [OpenStruct]
      ############################
      def walkthru_cmd_opts
        @walkthru_cmd_opts ||= OpenStruct.new
      end

      # If the command we are running manipulates a title or version (the target), then
      # before we process the options given on the commandline or show the walkthru menu,
      # we need to know the 'current' values.
      #
      # The current values are:
      #
      # For titles:
      # - the default values for new titles, if it doesn't exist and we are adding it.
      #   NB: at the moment there are no default values for new titles.
      # - the current values for the title, if it exists and we are editing it
      #
      # For versions:
      # - The default values for new versions, if we are adding the first one in a title
      # - The values of the most recent version, if we are adding a subsequent one for the title
      # - The values of this version, if we are editing an existing one
      #
      # For xadm configuration:
      # - The values from the config file and/or credentials from the keychain
      #   - keychain values are not displayed in walkthru, but are shown to be
      #     already set, or needed.
      #
      # @return [OpenStruct]
      #####################
      def current_opt_values
        return @current_opt_values if @current_opt_values

        @current_opt_values = OpenStruct.new

        opts_defs = Xolo::Admin::Options::COMMANDS[cli_cmd.command][:opts]

        # config?
        if cli_cmd.command == CONFIG_CMD
          # Xolo::Admin::Configuration::KEYS.each_key { |key| @current_opt_values[key] = config.send(key) }
          opts_defs.each_key { |key| @current_opt_values[key] = config.send(key) }

          # titles
        elsif title_command?

          # adding a new one? just use defaults, if there are any
          if add_command?
            # defaults
            opts_defs.each do |key, deets|
              next unless deets[:default]

              @current_opt_values[key] = deets[:default].is_a?(Proc) ? deets[:default].call : eets[:default]
            end

          # editing? just use the current values
          elsif edit_command?
            current_title = Xolo::Admin::Title.fetch cli_cmd.title, server_cnx
            opts_defs.each_key { |key| @current_opt_values[key] = current_title.send(key) }
          end

        # versions
        elsif version_command?

          # adding a new one?
          if add_command?
            prev_version = Xolo::Admin::Title.latest_version cli_cmd.title, server_cnx

            # Use the most recent version if we have one
            if prev_version
              pvers = Xolo::Admin::Version.fetch cli_cmd.title, prev_version, server_cnx
              opts_defs.each do |key, deets|
                next if deets[:do_not_inherit]

                val = pvers.send key
                next unless val

                @current_opt_values[key] = val
              end
              # publish date is always today to start with
              @current_opt_values[:publish_date] = Date.today.to_s
            # no prev version, so use the defaults
            else
              opts_defs.each do |key, deets|
                next unless deets[:default]

                @current_opt_values[key] = deets[:default].is_a?(Proc) ? deets[:default].call : deets[:default]
              end
            end

          # editing? just use the current values
          elsif edit_command?
            # do stuff here to fetch current values from the server.
            current_vers = Xolo::Admin::Version.fetch cli_cmd.title, cli_cmd.version, server_cnx
            opts_defs.each_key { |key| @current_opt_values[key] = current_vers.send(key) }
          end
        end

        @current_opt_values
      end

      # The options for the running command that are marked as :required
      ###########################
      def required_values
        @required_values ||= Xolo::Admin::Options::COMMANDS[cli_cmd.command][:opts].select { |_k, v| v[:required] }
      end

    end # module Options

  end # module Admin

end # module Xolo
