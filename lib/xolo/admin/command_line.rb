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

    # Module for parsing and validating the xadm options from the commandline
    module CommandLine

      # Module Methods
      ##########################
      ##########################

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # Instance Methods
      ##########################
      ##########################

      # Parse ARGV.
      #
      # First we use Optimist to parse the global opts and populate
      # the OpenStruct Xolo::Admin::Options.global_opts
      #
      # Then we look at the next arguments on the command line
      # (things without a - or -- ) and
      # populate the OpenStruct Xolo::Admin::Options.cli_cmd
      #
      # Then we use Optimist again to look at any remaining
      # options, which apply to the command, and populate
      # the OpenStruct Xolo::Admin::Options.cli_cmd_opts
      #
      ################################################
      def parse_cli
        # if we ask for help at all, we never do walkthru
        if ARGV.include?(Xolo::Admin::Options::HELP_OPT) || ARGV.include?(Xolo::Admin::Options::HELP_CMD)
          ARGV.delete '-w'
          ARGV.delete '--walkthru'
        end

        # save the global opts hash from optimist into our OpenStruct
        parse_global_cli.each { |k, v| global_opts[k] = v }

        # Now parse the rest of the command line, getting the
        # command its its args into cli_cmd, and the opts for them
        # into cli_cmd_opts
        parse_command_cli
      end

      # Use Optimist to parse the global opts, stopping when it hits a known command
      # This also generates the top level --help output
      #
      # @return [Hash] The global opts from the command line, parsed by optimist
      ################################################
      def parse_global_cli
        # set this so its available inside the optimist options block
        executable_file = Xolo::Admin::EXECUTABLE_FILENAME

        Optimist.options do
          banner 'Name:'
          banner "  #{executable_file}, A command-line tool for managing Software Titles and Versions in Xolo."

          banner "\nUsage:"
          banner "  #{usage}"

          banner "\nGlobal Options:"

          # add a blank line between each of the cli options in the help output
          # NOTE: chrisl added this to the optimist.rb included in this project.
          insert_blanks

          version Xolo::VERSION

          # The global opts
          ## manually set :version and :help here, or they appear at the bottom of the help
          opt :version, 'Print version and exit'
          opt :help, 'Show this help and exit'

          # This actually sets the optimist global options and their help blurbs
          #
          Xolo::Admin::Options::GLOBAL_OPTIONS.each do |opt_key, deets|
            opt opt_key, deets[:desc], short: deets[:cli]
          end
          stop_on Xolo::Admin::Options::COMMANDS.keys

          # everything below is just more help output

          banner "\nCommands:"
          Xolo::Admin::Options::COMMANDS.each do |cmd, deets|
            banner format('  %-20s %s', cmd, deets[:desc])
          end

          banner "\nCommand Targets:"
          banner Xolo::Admin::Options::DFT_CMD_TITLE_ARG_BANNER
          banner Xolo::Admin::Options::DFT_CMD_VERSION_ARG_BANNER

          banner "\nCommand Options:"
          banner "  Use '#{executable_file} help command'  or '#{executable_file} command #{Xolo::Admin::Options::HELP_OPT}' to see command-specific help."

          banner "\nExamples:"
          banner "  #{executable_file} add-title google-chrome <options...>"
          banner "    Add a new title 'google-chrome' to Xolo,"
          banner '    specifying all options on the command line'

          banner "\n  #{executable_file} --walkthru add-title google-chrome"
          banner "    Add a new title 'google-chrome' to Xolo,"
          banner '    providing options interactively'

          banner "\n  #{executable_file} edit-title google-chrome <options...>"
          banner "    Edit the existing title 'google-chrome',"
          banner '    specifying all options on the command line'

          banner "\n  #{executable_file} delete-title google-chrome"
          banner "    Delete the existing title 'google-chrome' from Xolo,"
          banner '    along with all of its versions.'

          banner "\n  #{executable_file} add-version google-chrome 95.144.21194 <options...>"
          banner "    Add a new version number 95.144.21194 to the title 'google-chrome'"
          banner '    specifying all options on the command line.'
          banner '    Options not provided are inherited from the previous version, if available.'

          banner "\n  #{executable_file} edit-version google-chrome 95.144.21194 <options...>"
          banner "    Edit version number 95.144.21194 of the title 'google-chrome'"
          banner '    specifying all options on the command line'

          banner "\n  #{executable_file} delete-version google-chrome 95.144.21194"
          banner "    Delete version 95.144.21194 from the title 'google-chrome'"

          banner "\n  #{executable_file} search chrome"
          banner "    List all titles that contain the string 'chrome'"
          banner '    and its available versions'

          banner "\n  #{executable_file} report google-chrome"
          banner "    Report computers with any version of title 'google-chrome' installed"

          banner "\n  #{executable_file} report google-chrome 95.144.21194"
          banner "    Report computers with version 95.144.21194 of title 'google-chrome' installed"

          banner "\n  #{executable_file} list-groups"
          banner '    List all computer groups in Jamf Pro'
        end # Optimist.options
      end

      # Once we run this, the global opts have been parsed
      # and ARGV should contain our command, any args it takes,
      # and then any options for that command and args.
      #
      # e.g.  the command might be 'edit-version'
      # and the args are a title, and a version to edit.
      # Anything after that are the options for doing the editing
      # (unless we are using --walkthru)
      #
      # @return [void]
      ################################################
      def parse_command_cli
        # This gets the command (like config or add-title) and any args
        # like a title and/or a version
        # putting them into cli_cmd
        parse_cmd_and_args # unless cli_cmd.command

        # if we are using --walkthru, all remaining command options are ignored,
        # so just return.
        # The walkthru_cmd_opts will be populated by the interactive
        # process
        return if walkthru?

        # parse_cmd_opts uses Optimist to get the --options that go
        # with the command and its args.
        # we loop thru them (its a hash) and save them into our
        # cli_cmd_optsOpenStruct
        parse_cmd_opts.each { |k, v| cli_cmd_opts[k] = v }
        # Now merge in current_opt_values for anything not given on the cli
        # This is how we inherit values, or apply defaults
        current_opt_values.to_h.each do |k, v|
          next if cli_cmd_opts["#{k}_given"]

          cli_cmd_opts[k] = v unless v.pix_blank?
        end

        # Validate the options given on the commandline
        validate_cli_cmd_opts

        # now cli_cmd_opts contains all the data for
        # processing whatever we're processing, so do the internal consistency checks
        validate_internal_consistency cli_cmd_opts

        # If we got here, everything in Xolo::Admin::Options.cli_cmd_opts is good to go
        # and can be sent to the server for processing.
      end # parse_command_cli

      # Get the xadm command, and its args (title, maybe version, etc)
      # from the Command Line.
      # They get stored in the cli_cmd OpenStruct.
      #
      # We don't use optimist for this, we just examine the first items of
      # ARGV until we hit one starting with a dash.
      #
      ##################################################################
      def parse_cmd_and_args
        # next item will be the command we are executing
        cli_cmd.command = ARGV.shift

        # if there is no command, treat it like `xadm --help`
        return if reparse_global_cli_for_help?

        # we have a command, validate it
        validate_cli_command

        # Some commands, like 'config', always do walkthru
        return if reparse_global_cli_for_mandatory_walkthru?

        # if the command is 'help'
        # then
        #   'xadm [globalOpts] help' becomes 'xadm --help'
        # and
        #   'xadm [globalOpts] help command' becomes 'xadm [globalOpts] command --help'
        #
        # in those forms, Optimist will deal with displaying the help.
        #
        if cli_cmd.command == Xolo::Admin::Options::HELP_CMD

          # 'xadm [globalOpts] help' becomes 'xadm --help' (via the reparse method)
          cli_cmd.command = ARGV.shift
          return if reparse_global_cli_for_help?

          # we have a new command, for which we are getting help. Validate it
          validate_cli_command

          # 'xadm [globalOpts] help command' becomes 'xadm [globalOpts] command --help'
          ARGV.unshift Xolo::Admin::Options::HELP_OPT
        end
        # if we are here any any part of ARGV is --help, nothing more to do here.
        return if ARGV.include?(Xolo::Admin::Options::HELP_OPT)

        # log in now, cuz we need the server to validate the rest of the
        # command line
        #
        # TODO: Be pickier about which commands actually need the server, and
        # only log in for them.
        #################
        login

        # What kind of command do we have, since we know it isn't 'help' if we
        # are here.
        if title_command?
          # the next item is the title
          cli_cmd.title = ARGV.shift
          validate_cli_title

        elsif version_command?
          # the next item is the title and the one after that might be a version
          cli_cmd.title = ARGV.shift
          validate_cli_title

          cli_cmd.version = ARGV.shift
          validate_cli_version

        elsif title_or_version_command?
          # the next item is the title and the one after that might be a version
          cli_cmd.title = ARGV.shift
          validate_cli_title

          cli_cmd.version = ARGV.shift unless ARGV.first.to_s.start_with? Xolo::DASH
          validate_cli_version if cli_cmd.version

        end # if
      end

      # Are we showing the full help? If so, re-parse the global opts
      ##################################################################
      def reparse_global_cli_for_help?
        cmdstr = cli_cmd.command.to_s
        return false unless cmdstr.empty? || cmdstr.start_with?(Xolo::DASH)

        ARGV.unshift Xolo::Admin::Options::HELP_OPT
        parse_global_cli
        true
      end

      # Are we doing mandatory walkthru? If so, re-parse the global opts
      ##################################################################
      def reparse_global_cli_for_mandatory_walkthru?
        return false if ARGV.include? Xolo::Admin::Options::HELP_OPT
        return false unless cli_cmd.command == Xolo::Admin::Options::CONFIG_CMD

        ARGV.clear
        ARGV << '--walkthru'
        ARGV << '--debug' if global_opts.debug
        ARGV << '--auto-confirm' if global_opts.auto_confirm
        ARGV << Xolo::Admin::Options::CONFIG_CMD

        parse_cli
        true
      end

      # Parse the options for the command.
      # This returns a hash from Optimist
      ##################################################################
      def parse_cmd_opts
        cmd = cli_cmd.command
        return if cmd == Xolo::Admin::Options::HELP_CMD || cmd.to_s.empty?

        # set these for use inside the optimist options block
        ###
        executable_file = Xolo::Admin::EXECUTABLE_FILENAME
        cmd_desc = Xolo::Admin::Options::COMMANDS.dig cmd, :desc
        cmd_usage = Xolo::Admin::Options::COMMANDS.dig cmd, :usage
        cmd_display = Xolo::Admin::Options::COMMANDS.dig cmd, :display
        cmd_opts = Xolo::Admin::Options::COMMANDS.dig cmd, :opts

        title_cmd = title_command?
        vers_cmd = version_command?
        title_or_vers_command = title_or_version_command?
        add_command = add_command?
        edit_command = edit_command?
        arg_banner = Xolo::Admin::Options::COMMANDS.dig(cmd, :arg_banner)
        arg_banner ||= Xolo::Admin::Options::DFT_CMD_TITLE_ARG_BANNER

        # The optimist parser and help generator
        # for the command options
        Optimist.options do
          # NOTE: extra newlines are added to the front of strings, cuz
          # optimist's 'banner' method chomps the ends.
          banner 'Command:'
          banner "  #{cmd}, #{cmd_desc}"

          banner "\nUsage:"
          usage = cmd_usage || "#{executable_file} #{cmd_display} [options]"
          banner "  #{usage}"

          unless arg_banner == :none
            banner "\nArguments:"
            banner arg_banner
            banner Xolo::Admin::Options::DFT_CMD_VERSION_ARG_BANNER if vers_cmd || title_or_vers_command
          end

          if cmd_opts
            banner "\nOptions:"

            # add a blank line between each of the cli options
            # NOTE: chrisl added this to the optimist.rb included in this project.
            insert_blanks

            # create the optimist options for the command
            cmd_opts.each do |opt_key, deets|
              next unless deets[:cli]

              # Required opts are only required when adding.
              # when editing, they should already exist
              required = deets[:required] && add_command

              desc = deets[:desc]
              desc = "#{desc}REQUIRED" if required

              # booleans are CLI flags defaulting to false
              # everything else is a string that we will convert as we validate later
              type = deets[:type] == :boolean ? :boolean : :string

              # here we actually set the optimist opt.
              opt opt_key, desc, short: deets[:cli], type: type, required: required, multi: deets[:multi]
            end # opts_to_use.each
          end # if cmd_opts
        end # Optimist.options
      end

      # @return [Boolean] does the command we're running deal with titles?
      #######################################
      def title_command?
        Xolo::Admin::Options::COMMANDS[cli_cmd.command][:target] == :title
      end

      # @return [Boolean] does the command we're running deal with versions?
      #######################################
      def version_command?
        Xolo::Admin::Options::COMMANDS[cli_cmd.command][:target] == :version
      end

      # @return [Boolean] does the command we're running deal with either titles or versions?
      #######################################
      def title_or_version_command?
        Xolo::Admin::Options::COMMANDS[cli_cmd.command][:target] == :title_or_version
      end

      # @return [Boolean] does the command we're running not deal with titles or versions?
      #   e.g. 'config' or 'help'
      #######################################
      def no_target_command?
        !Xolo::Admin::Options::COMMANDS[cli_cmd.command][:target]
      end

      # @return [Boolean] does the command we're running add a title or version to xolo?
      #######################################
      def add_command?
        Xolo::Admin::Options::ADD_COMMANDS.include? cli_cmd.command
      end

      # @return [Boolean] does the command we're running add a title or version to xolo?
      #######################################
      def edit_command?
        Xolo::Admin::Options::EDIT_COMMANDS.include? cli_cmd.command
      end

    end # module CommandLine

  end # module Admin

end # module Xolo
