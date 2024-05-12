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

# frozen_string_literal: true

module Xolo

  module Admin

    # module for defining and parsing the CLI and Interactive options
    # for xadm
    module Options

      # Constants
      #########################
      #########################

      # See the definition for Xolo::Core::BaseClasses::Title::ATTRIBUTES
      # NOTE: Optimist automatically provides --version -v and --help -h
      GLOBAL_OPTIONS = {
        walkthru: {
          label: 'Run Interactively',
          walkthru: false,
          cli: :w,
          desc: <<~ENDDESC
            Run xadm in interactive mode
            This causes xadm to present an interactive, menu-and-
            prompt-driven interface. All command-options given on the
            command line are ignored, and will be gathered
            interactively.
            Using the command 'config' will always imply --walkthru.
          ENDDESC
        },

        auto_confirm: {
          label: 'Auto Approve',
          cli: :a,
          walkthru: false,
          desc: <<~ENDDESC
            Do not ask for confirmation before commands that require it:
            add-title, edit-title, delete-title, add-version, edit-version,
            release-version, delete-version.
            This is mostly used for automating xolo.
            Ignored if using --walkthru.
            WARNING: Be careful that all values are correct.
          ENDDESC
        },

        debug: {
          label: 'Debug',
          cli: :d,
          walkthru: false,
          desc: <<~ENDDESC
            Run xadm in debug mode
            This causes more verbose output and full backtraces
            to be printed on errors
          ENDDESC
        }
      }.freeze

      # The xadm commands

      LIST_TITLES_CMD = 'list-titles'
      ADD_TITLE_CMD = 'add-title'
      EDIT_TITLE_CMD = 'edit-title'
      DELETE_TITLE_CMD = 'delete-title'

      LIST_VERSIONS_CMD = 'list-versions'
      ADD_VERSION_CMD = 'add-version'
      EDIT_VERSION_CMD = 'edit-version'
      PILOT_VERSION_CMD = 'pilot-version'
      RELEASE_VERSION_CMD = 'release-version'
      DELETE_VERSION_CMD = 'delete-version'

      INFO_CMD = 'info' # info on a title or version
      SEARCH_CMD = 'search' # search for titles
      REPORT_CMD = 'report' # report on installations
      CONFIG_CMD = 'config' # configure xadm

      LIST_GROUPS_CMD = 'list-groups'
      LIST_CATEGORIES_CMD = 'list-categories'

      STATUS_CMD = 'status'
      HELP_CMD = 'help'

      HELP_OPT = '--help'

      DFT_CMD_TITLE_ARG_BANNER = "  title:     The unique name of a title in Xolo, e.g. 'google-chrome'"
      DFT_CMD_VERSION_ARG_BANNER = "  version:   The version of the title you are working with. e.g. '12.34.5'"

      TARGET_TITLE_PLACEHOLDER = 'TARGET_TITLE_PH'
      TARGET_VERSION_PLACEHOLDER = 'TARGET_VERSION_PH'

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
          # Should server_route be part of the Xolo::Admin::Title class?
          # probably, since using it will be a method of Xolo::Admin::Title
          server_route: { method: 'POST', path: '/add-title' }
        },

        # TODO: Implement PATCH, or just PUT ?
        EDIT_TITLE_CMD => {
          desc: 'Edit an exising software title',
          display: "#{EDIT_TITLE_CMD} title",
          opts: Xolo::Admin::Title.cli_opts,
          walkthru_header: "Editing Xolo Title '#{TARGET_TITLE_PLACEHOLDER}'",
          process_method: :edit_title,
          target: :title
        },

        DELETE_TITLE_CMD => {
          desc: 'Delete a software title, and all of its versions',
          display: "#{DELETE_TITLE_CMD} title",
          opts: {},
          process_method: :delete_title,
          target: :title
        },

        LIST_VERSIONS_CMD => {
          desc: 'List all versions of a title.',
          display: "#{LIST_VERSIONS_CMD} title",
          opts: {},
          target: :title,
          process_method: :list_versions
        },

        ADD_VERSION_CMD => {
          desc: 'Add a new version to a title',
          display: "#{ADD_VERSION_CMD} title version",
          opts: Xolo::Admin::Version.cli_opts,
          walkthru_header: "Adding Version '#{TARGET_VERSION_PLACEHOLDER}' to Xolo Title '#{TARGET_TITLE_PLACEHOLDER}'",
          process_method: :add_version,
          target: :version
        },

        # TODO: Implement PATCH, or just PUT ?
        EDIT_VERSION_CMD => {
          desc: 'Edit a version of a title',
          display: "#{EDIT_VERSION_CMD} title version",
          opts: Xolo::Admin::Version.cli_opts,
          walkthru_header: "Editing Version '#{TARGET_VERSION_PLACEHOLDER}' of Xolo Title '#{TARGET_TITLE_PLACEHOLDER}'",
          target: :version,
          process_method: :edit_version
        },

        PILOT_VERSION_CMD => {
          desc: 'Make the version available for piloting',
          display: "#{PILOT_VERSION_CMD} title version",
          opts: {},
          target: :version
        },

        RELEASE_VERSION_CMD => {
          desc: 'Make the version available for general installation.',
          display: "#{RELEASE_VERSION_CMD} title version",
          opts: {},
          target: :version
        },

        DELETE_VERSION_CMD => {
          desc: 'Delete a version from a title.',
          display: "#{DELETE_VERSION_CMD} title version",
          opts: {},
          target: :version,
          process_method: :delete_version
        },

        SEARCH_CMD => {
          desc: 'Search for titles in Xolo.',
          display: "#{SEARCH_CMD} title",
          opts: {},
          target: :title
        },

        INFO_CMD => {
          desc: 'Show details about a title, or a version of a title',
          display: "#{INFO_CMD} title [version]",
          opts: {},
          target: :title_or_version,
          process_method: :show_info
        },

        REPORT_CMD => {
          desc: 'Report installation data.',
          display: "#{REPORT_CMD} title [version]",
          opts: {},
          target: :title_or_version
        },

        CONFIG_CMD => {
          desc: 'Configure xadm. (Implies --walkthru)',
          display: "#{CONFIG_CMD}",
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

        STATUS_CMD => {
          desc: 'Show status of Xolo server',
          display: STATUS_CMD,
          opts: {},
          process_method: :server_status
        },

        HELP_CMD => {
          desc: 'Get help for a specifc command',
          display: 'help command',
          opts: {},
          no_login: true
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
        DELETE_TITLE_CMD, DELETE_VERSION_CMD,
        PILOT_VERSION_CMD, RELEASE_VERSION_CMD
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
      #######################
      def walkthru?
        global_opts.walkthru
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
              opts_defs.each do |key, _deets|
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
