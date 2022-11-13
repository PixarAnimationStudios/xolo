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
# e.g. opts[key] or method-style when you know the key e.g. opts.title
require 'ostruct'
require 'optimist'

module Xolo

  module Admin

    # module for defining and parsing the CLI and Interactive options
    # for xadm
    module Options

      #### Constants
      #########################

      # See the definition for Xolo::Core::BaseClasses::Title::ATTRIBUTES
      # NOTE: Optimist automatically provides --version -v and --help -h
      GLOBAL_OPTIONS = {
        walkthru: {
          label: 'Run',
          walkthru: false,
          cli: :w,
          desc: <<~ENDDESC
            Run xadm in interactive mode
            This causes xadm to present an interactive, prompt-and-
            menu-driven interface. All command-options given on the
            command line are ignored, and will be gathered
            interactively
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
          cli: :none,
          walkthru: false,
          desc: <<~ENDDESC
            Run xadm in debug mode
            This causes more verbose output and full backtraces
            to be printed on errors
          ENDDESC
        }
      }.freeze

      # The xadm commands

      ADD_TITLE_CMD = 'add-title'
      EDIT_TITLE_CMD = 'edit-title'
      DELETE_TITLE_CMD = 'delete-title'
      ADD_VERSION_CMD = 'add-version'
      EDIT_VERSION_CMD = 'edit-version'
      DELETE_VERSION_CMD = 'delete-version'
      RELEASE_VERSION_CMD = 'release-version'
      SEARCH_CMD = 'search'
      REPORT_CMD = 'report'
      HELP_CMD = 'help'

      COMMANDS = {
        ADD_TITLE_CMD => {
          desc: 'Add a new software title',
          display: "#{ADD_TITLE_CMD} title",
          opts: Xolo::Core::BaseClasses::Title.cli_opts,
          target: :title
        },

        EDIT_TITLE_CMD => {
          desc: 'Edit an exising software title',
          display: "#{EDIT_TITLE_CMD} title",
          opts: Xolo::Core::BaseClasses::Title.cli_opts,
          target: :title
        },

        DELETE_TITLE_CMD => {
          desc: 'Delete a software title, and all of its versions',
          display: "#{DELETE_TITLE_CMD} title",
          opts: {},
          target: :title
        },

        ADD_VERSION_CMD => {
          desc: 'Add a new version to a title',
          display: "#{ADD_VERSION_CMD} title version",
          opts: Xolo::Core::BaseClasses::Version.cli_opts,
          target: :version
        },

        EDIT_VERSION_CMD => {
          desc: 'Edit a version of a title',
          display: "#{EDIT_VERSION_CMD} title version",
          opts: Xolo::Core::BaseClasses::Version.cli_opts,
          target: :version
        },

        RELEASE_VERSION_CMD => {
          desc: 'Release a version to all targets.',
          display: "#{DELETE_VERSION_CMD} title version",
          opts: {},
          target: :version
        },

        DELETE_VERSION_CMD => {
          desc: 'Delete a version from a title.',
          display: "#{DELETE_VERSION_CMD} title version",
          opts: {},
          target: :version
        },

        SEARCH_CMD => {
          desc: 'Search for titles in Xolo.',
          display: "#{SEARCH_CMD} title",
          opts: {}
        },

        REPORT_CMD => {
          desc: 'Report installation data.',
          display: "#{REPORT_CMD} title [version]",
          opts: {}
        },

        HELP_CMD => {
          desc: 'Get help for a specifc command',
          display: 'help command',
          opts: {}
        }
      }.freeze

      # The commands that add something to xolo - how their options are processed and validated
      # differs from those commands that just edit or report things.
      ADD_COMMANDS = [ADD_TITLE_CMD, ADD_VERSION_CMD].freeze

      #### Module Methods
      #############################

      # Are we running in interactive mode?
      def self.walkthru?
        Xolo::Admin::Options.global_opts.walkthru
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
      def self.global_opts
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
      def self.cli_cmd
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
      def self.cli_cmd_opts
        @cli_cmd_opts ||= OpenStruct.new
      end

      # Walkthru Command Opts - the options given via walkthrough
      # for processing an xadm command.
      #
      # This is intially set with the default, inherited, or existing
      # values for the object being created or edited.
      #
      # Before the walk through starts, it duped and the dup
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
      def self.walkthru_cmd_opts
        @walkthru_cmd_opts ||= OpenStruct.new
      end

      # the 'current' values for the cli opts of the object being manipulated by xadm
      # (either a title or a version)
      #
      # when xadm takes all options from the commandline,
      # those options are merged with these to get the set that must be validated for
      # internal consistency.
      #
      # When getting all options via walkthru, these are used as the starting point
      # and as values are changed, they are validated individually, and for internal consistency
      # each time the menu is re-drawn.
      #
      # When adding a new one, there is no current one, so the current values are
      # either nil, or any default defined in the options for the command, or if we are
      # making a new version, 'current' values are inherited from the prev. version.
      #
      # When editing an existing object, the current values come from that existing one.
      # via the server.
      #
      # These are then used for the walkthru menus, or if not walkthru, the values
      # given on the commandline are merged with these to create the set of values
      # to be validated together before being applied.
      #
      #
      # @return [OpenStruct]
      def self.current_opt_values
        return @current_opt_values if @current_opt_values

        @current_opt_values = OpenStruct.new

        # adding a new object
        if Xolo::Admin::CommandLine.add_command?

          # set any that are defined as default
          opts_defs = Xolo::Admin::Options::COMMANDS[Xolo::Admin::Options.cli_cmd.command][:opts]
          opts_defs.each { |key, deets| @current_opt_values[key] = deets[:default] if deets[:default] }

          # new titles never inherit, they just start with defaults, so  we are done
          return @current_opt_values unless Xolo::Admin::CommandLine.version_command?

          # if we are here, its a version, so we'll grab the previous one and use
          # it to inherit its values.
          # This is where we'll fetch it from the xolo server as a JSON hash, some day
          prev_version_data = nil
          prev_version_data.each { |key, val| @current_opt_values[key] = val } if prev_version_data

          return @current_opt_values
        end

        # editing an existing object

        # TODO: When the server is functional, this is where we
        # reach out to grab the existing object, and we'll get back a JSON hash of its
        # data.
        # Until there, here's a hard-coded hash for a title
        existing_obj_data = {
          title: 'foo',
          display_name: 'Foo',
          description: 'Installs Foo',
          publisher: 'Foo Industries',
          app_name: 'Foo.app',
          app_bundle_id: 'com.foo.foo',
          version_script: nil,
          target_group: %w[target-group-one target-group-two],
          excluded_group: %w[exclude-group-one exclude-group-two],
          expiration: 45,
          expiration_path: ['/tmp/foochrisl', '/tmp/foochrisl2'],
          self_service: true,
          self_service_category: 'All The Foos',
          self_service_icon: nil,
          created_by: 'chrisl',
          creation_date: (Time.now - 2_535_876),
          modified_by: 'chrisltest',
          modification_date: Time.now
        }

        existing_obj_data.each { |key, val| @current_opt_values[key] = val }

        @current_opt_values
      end

      # The options for the running command that are marked as :required
      def self.required_values
        @required_values ||= COMMANDS[cli_cmd.command][:opts].select { |_k, v| v[:required] }
      end

    end # module Options

  end # module Admin

end # module Xolo
