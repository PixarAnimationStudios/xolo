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

# frozen_string_literal: true

# Yes we're using a OpenStruct for our @opts, even though it's very slow.
# It isn't so slow that it's a problem for processing a CLI tool.
# The benefit is being able to use either Hash-style references
# e.g. opts[key] or method-style when you know the key e.g. opts.title_id
require 'ostruct'
require 'optimist'

module Xolo

  module Admin

    module Options

      #### Constants
      #########################

      NONE = 'none'

      ADD_TITLE_CMD = 'add-title'
      EDIT_TITLE_CMD = 'edit-title'
      DELETE_TITLE_CMD = 'delete-title'
      ADD_VERSION_CMD = 'add-version'
      EDIT_VERSION_CMD = 'edit-version'
      DELETE_VERSION_CMD = 'delete-version'
      HELP_CMD = 'help'

      # Hash Keys [Symbol] Used internally to access the option values in the @options
      # hash returned by Optimist, and as instance variables for the current value.
      # e.g. @desc = the current description,  @options.desc, the one provided in the
      # options.
      #
      # option settings
      #
      # - label: [String] to be displayed in admin interation, walkthru, err msgs
      #    e.g. 'Title ID'
      #
      # - required: [Boolean] Must be provided when making a new title, cannot be
      #   deleted from existing titles.
      #
      # - walkthru: [Boolean] Use as an item in the menu-driven, interactive process
      #   to get all options from admin. Default is true. Should be false for values
      #   that are prompted-for separately from the full menu, e.g. title_id
      #
      # - cli: [false, Symbol] If false, this option is never taken as a cli
      #   option, but may be used as a cli argument, e.g. in this command:
      #      xadm edit-title my-title-id <options>
      #   'edit-title' is the subcommand and 'my-title-id' is the argument.
      #
      #   If a one-letter Symbol, this is the 'short' cli option, e.g. the Symbol :d
      #   defines the cli option '-d' which is used as the short option for --description
      #   NOTE: the long cli options are just the option keys preceded with -- and
      #   underscores converted to dashes, so :title_id becomes --title-id
      #
      #   If the symbol :none is used, there is no short variation of the CLI option.
      #
      # - type:  If no default, and no validate, this is used by Optimist to validate
      #   the value given on the commandline
      #
      # - default: [String, Numeric, Boolean] the default value nothing is
      #   provided or inherited
      #
      # - validate: [Boolean, Symbol] how to validate values for this option.
      #   - If truthy call method Xolo::Admin::Validate.<value_key>  e.g. Xolo::Admin::Validate.title_id(val)
      #   - If a Symbol, its a nonstandard method to call on the Xolo::Admin::Validate module
      #     e.g. :non_empty_array will validate the value using  Xolo::Admin::Validate.non_empty_array(val)
      #   - If falsy: no validation
      #
      # - invalid_msg: [String] custom message to display when invalid
      #
      # - immutable: [Boolean] This value can only be set when created a new title.
      #   When editing an existing title, it cannot be changed.
      #
      # - desc: [String] helpful text explaining what the option means. Displayed
      #   during walkthru, in help messages, and in some err messages.
      #
      # - sub_commands: [Array<String>] the subcommands that will take this option
      #
      TITLE_OPTIONS = {

        title_id: {
          label: 'Title ID',
          required: true,
          cli: false,
          type: :string,
          immutable: true,
          walkthru: false,
          validate: :validate_title_id,
          sub_commands: [], # no subcommants take the title id - its always the arg of a subcommand
          invalid_msg: 'Not a valid title id! Must be lowercase alphanumeric and dashes only, cannot already exist in xolo.',
          desc: <<~ENDDESC
            A unique string identifying this Software Title, e.g. 'folio'.
            The same as a 'basename' in d3.
            Must contain only lowercase letters, numbers, and dashes.
          ENDDESC
        },

        display_name: {
          label: 'Display Name',
          required: true,
          cli: :n,
          type: :string,
          validate: /\w\w\w+/,
          invalid_msg: '"Not a valid display name, must be at least three characters.',
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            A human-friendly name for the Software Title, e.g. 'Google Chrome', or
            'NFS Menubar'. Must be at least three characters long.
          ENDDESC
        },

        description: {
          label: 'Description',
          required: true,
          cli: :d,
          type: :string,
          validate: :validate_title_description,
          invalid_msg: "Not a valid description name, must be at least 20 characters. Include a useful dscription of what the software does: URLs, developer names, etc. Do NOT use, e.g. 'Installs Google Chrome' for the title 'GoogleChrome', that just wastes everyone's time.",
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            A useful dscription of what the software installed by this title does,
            You can also include URLs, developer names, support info, etc.
            DO NOT use, e.g. 'Installs Google Chrome' for the title 'GoogleChrome',
            that just wastes everyone's time. Must be at least 20 Characters.
          ENDDESC
        },

        publisher: {
          label: 'Publisher',
          required: true,
          cli: :p,
          type: :string,
          validate: /\w\w\w+/,
          invalid_msg: '"Not a valid Publisher, must be at least three characters.',
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            The company or entity that publishes this title, e.g. 'Apple Inc.'
            or 'Pixar Animation Studios'.
          ENDDESC
        },

        app_bundle_id: {
          label: 'The bundle ID of the .app',
          required: true,
          validate: /\w\w\w+/,
          type: :string,
          invalid_msg: '"Not a valid Publisher, must be at least three characters.',
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            If this title installs a .app bundle, the app's bundle-id must be provided.
            This is found in the CFBundleIdentifier key of the app's Info.plist.
            e.g. 'com.google.chrome'
            If the title does not install a .app bundle, leave this blank
          ENDDESC
        },

        app_name: {
          label: 'The name of the .app',
          required: true,
          validate: /\w\w\w+/,
          type: :string,
          invalid_msg: '"Not a valid Publisher, must be at least three characters.',
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            If this title installs a .app bundle, the app's name must be provided.
            This the name of the bundle iteslf on disk, e.g. 'Google Chrome.app'.
            If the title does not install a .app bundle, leave this blank
          ENDDESC
        },

        targets: {
          label: 'Target Computer Groups',
          default: NONE,
          validate: :jamf_group,
          type: :strings,
          invalid_msg: "Invalid target. All targets must be an existing Jamf Computer Group, 'all', or '#{NONE}'.",
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            A comma-separated list of Jamf Computer Groups identifying computers
            that will automatically have this title installed. Use 'all' to auto-
            install on all computers (except those that are excluded).
          ENDDESC
        },

        exclusions: {
          label: 'Excluded Computer Groups',
          validate: :jamf_group,
          default: NONE,
          type: :strings,
          invalid_msg: "Invalid exclusion. All exclusions must be an existing Jamf Computer Group,  or '#{NONE}'.",
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            A comma-separated list of Jamf Computer Groups identifying computers
            that will not be able to install this, unless forced. If a computer is
            in both the targets and the exclusions, the exclusion wins.
          ENDDESC
        },

        expiration: {
          label: 'Expire After Days',
          default: 0,
          validate: /\A\d+\z/,
          type: :integer,
          invalid_msg: 'Invalid expiration period. Must be an integer number of days. 0 for no expiration.',
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            If the all of the executables listed in 'Expiration Paths' have not been
            used in this number of days, the title is uninstalled from the computer.
          ENDDESC
        },

        expiration_paths: {
          label: 'Expiration Paths',
          validate: true,
          type: :strings,
          invalid_msg: "Invalid expiration paths. Must at least one absolute path starting with a '/' and containing at least one more non-adjacent '/'.",
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            Paths to executables that must come to the foreground of a user's GUI session
            to be considered 'usage' of this title.
          ENDDESC
        },

        self_service: {
          label: 'Show in Self Service',
          validate: true,
          type: :boolean,
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            Should this title be available in Self Service?
            If so, and there are defined target groups, will only be
            available to non-excluded computers in those groups.
            Self Service is not available for titles with the target 'all'.
          ENDDESC
        },

        self_service_category: {
          label: 'Self Service Category',
          validate: true,
          type: :string,
          sub_commands: [ADD_TITLE_CMD, EDIT_TITLE_CMD],
          desc: <<~ENDDESC
            The Category in which to display this title in Self Service
          ENDDESC
        },

        self_service_icon: {
          label: 'Self Service Icon',
          validate: true,
          type: :string,
          sub_commands: %w[add-title edit-title],
          desc: <<~ENDDESC
            The icon to use for this title in Self Service
          ENDDESC
        }

      }.freeze

      # See the definition for TITLE_OPTIONS
      VERSION_OPTIONS = {

      }.freeze

      # See the definition for TITLE_OPTIONS
      # NOTE: Optimist automatically provides --version -v and --help -h
      GLOBAL_OPTIONS = {
        walkthru: {
          label: 'Run',
          walkthru: false,
          cli: :w,
          desc: <<~ENDDESC
            Run xadm in interactive mode.
            This causes xadm to present an interactive, prompt-and-
            menu-driven interface. All other commandline options
            are ignored, and will be gathered interactively.
          ENDDESC
        },

        debug: {
          label: 'Debug',
          cli: :none,
          walkthru: false,
          desc: <<~ENDDESC
            Run xadm in debug mode.
            This causes more verbose output and full backtraces
            to be printed on errors.
          ENDDESC
        }
      }.freeze

      SUB_COMMANDS = {
        ADD_TITLE_CMD => {
          desc: 'Add a new software title',
          display: "#{ADD_TITLE_CMD} title-id",
          opts: TITLE_OPTIONS
        },

        EDIT_TITLE_CMD => {
          desc: 'Edit an exising software title',
          display: "#{EDIT_TITLE_CMD} title-id",
          opts: TITLE_OPTIONS
        },

        DELETE_TITLE_CMD => {
          desc: 'Delete a software title, and all of its versions',
          display: "#{DELETE_TITLE_CMD} title-id",
          opts: TITLE_OPTIONS
        },

        ADD_VERSION_CMD => {
          desc: 'Add a new version to a title',
          display: "#{ADD_VERSION_CMD} title-id version",
          opts: VERSION_OPTIONS
        },

        EDIT_VERSION_CMD => {
          desc: 'Edit a version of a title',
          display: "#{EDIT_VERSION_CMD} title-id version",
          opts: VERSION_OPTIONS
        },

        DELETE_VERSION_CMD => {
          desc: 'Delete a version from a title.',
          display: "#{DELETE_VERSION_CMD} title-id version",
          opts: VERSION_OPTIONS
        },

        HELP_CMD => {
          desc: 'Get help for a specifc command',
          display: 'help command',
          opts: {}
        }
      }.freeze

      #### Module Methods
      #############################

      def self.global_opts
        @global_opts
      end

      def self.global_opts=(hash)
        @global_opts = OpenStruct.new hash
      end

      def self.cmd_opts
        @cmd_opts
      end

      def self.cmd_opts=(hash)
        @cmd_opts = OpenStruct.new hash
      end

    end # module Options

  end # module Admin

end # module Xolo
