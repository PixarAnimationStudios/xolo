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

# frozen_string_literal: true

module Xolo

  module Admin

    # Module for parsing and validating the xadm options from the commandline
    module CommandLine

      # Use optimist to parse ARGV.
      # This will handle the global opts and the xadm command,
      # populating Xolo::Admin::Options.global_opts, and Xolo::Admin::Options.cli_cmd
      ################################################
      def self.parse_cli
        # # accept --debug anywhere
        # if ARGV.delete '--debug'
        #   Xolo::Admin::Options.global_opts[:debug] = true
        #   Xolo::Admin::Options.global_opts[:debug_given] = true
        # end

        global_opts = parse_global_cli

        # save the global opts hash from optimist into our OpenStruct
        global_opts.each { |k, v| Xolo::Admin::Options.global_opts[k] = v }

        # Now parse the rest of the command line
        parse_command_cli
      end

      # use optimist to parse the global opts, stopping when it hits a known command
      def self.parse_global_cli
        # set this so its available inside the optimist options block
        executable_file = Xolo::Admin.executable.basename

        Optimist.options do
          banner 'Name:'
          banner "  #{executable_file}, A command-line tool for managing Software Titles and Versions in Xolo."

          banner "\nUsage:"
          banner "  #{Xolo::Admin.usage}"

          banner "\nGlobal Options:"

          # add a blank line between each of the cli options in the help output
          # NOTE: chrisl added this to the optimist.rb included in this project.
          insert_blanks

          version Xolo::VERSION

          # The global opts
          ## manually set :version and :help here, or they appear at the bottom of the help
          opt :version, 'Print version and exit'
          opt :help, 'Show this help and exit'

          Xolo::Admin::Options::GLOBAL_OPTIONS.each do |opt_key, deets|
            opt opt_key, deets[:desc], short: deets[:cli]
          end
          stop_on Xolo::Admin::Options::COMMANDS.keys

          banner "\nCommands:"
          Xolo::Admin::Options::COMMANDS.each do |cmd, deets|
            banner format('  %-20s %s', cmd, deets[:desc])
          end

          banner "\nCommand Targets:"
          banner Xolo::Admin::Options::DFT_CMD_TITLE_ARG_BANNER
          banner Xolo::Admin::Options::DFT_CMD_VERSION_ARG_BANNER

          banner "\nCommand Options:"
          banner "  Use '#{executable_file} help command'  or '#{executable_file} command --help' to see command-specific help."

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
        end # Optimist.options
      end

      # Parse the remaining command line, now that we know the xadm command
      # to be executed.
      # This gets the title & version, if needed, storing them in
      # Xolo::Admin::Options.cli_cmd.title and Xolo::Admin::Options.cli_cmd.version
      # then it gets the command options, populating Xolo::Admin::Options.cli_cmd_opts
      #######
      def self.parse_command_cli
        parse_cmd_and_args

        # if we are using --walkthru, all remaining command options are ignored, so just return.
        #
        # The Xolo::Admin::Options.walkthru_cmd_opts will be populated by the interactive
        # process
        return if Xolo::Admin::Options.global_opts.walkthru

        cmd_opts = parse_cmd_opts

        # save the opts hash from optimist into our OpenStruct
        cmd_opts.each { |k, v| Xolo::Admin::Options.cli_cmd_opts[k] = v }

        Xolo::Admin::Validate.cli_cmd_opts

        # add in current_opt_values for anything not given on the cli
        Xolo::Admin::Options.current_opt_values.each do |k, v|
          next if Xolo::Admin::Options.cli_cmd_opts["#{k}_given"]

          Xolo::Admin::Options.cli_cmd_opts[k] = v if v
        end

        # now Xolo::Admin::Options.cli_cmd_opts contains all the data for
        # processing whatever we're processing, so do the internal consistency check
        Xolo::Admin::Validate.internal_consistency Xolo::Admin::Options.cli_cmd_opts

        # If we got here, everything in Xolo::Admin::Options.cli_cmd_opts is good to go
        # and can be sent to the server for processing.
      end # parse_command_cli

      # Get the xadm command, and its args (title, and maybe version)
      # from the Command Line. They get stored in
      # Xolo::Admin::Options.cli_cmd
      def self.parse_cmd_and_args
        # next item will be the command we are executing
        Xolo::Admin::Options.cli_cmd.command = ARGV.shift

        # if there is no command, treat it like `xadm --help`
        return if reparse_global_cli_for_help?

        # we have a command, validate it
        validate_cli_command

        # if the command is 'help'
        # then
        #   'xadm [globalOpts] help' becomes 'xadm --help'
        # and
        #   'xadm [globalOpts] help command' becomes 'xadm [globalOpts] command --help'
        #
        if Xolo::Admin::Options.cli_cmd.command == Xolo::Admin::Options::HELP_CMD
          # 'xadm [globalOpts] help' becomes 'xadm --help' (via the reparse method)
          Xolo::Admin::Options.cli_cmd.command = ARGV.shift
          return if reparse_global_cli_for_help?

          # we have a new command, for which we are getting help. Validate it
          validate_cli_command
          # 'xadm [globalOpts] help command' becomes 'xadm [globalOpts] command --help'
          ARGV.unshift '--help'
        end
        return if ARGV.include?('--help')

        # Otherwise, the command is not 'help', so figure out what the next item
        # on the command line is
        if title_command?
          # the next item is the title
          Xolo::Admin::Options.cli_cmd.title = ARGV.shift
          validate_cli_title

        elsif version_command? || title_or_version_command?
          # the next item is the title and the one after that is a version
          Xolo::Admin::Options.cli_cmd.title = ARGV.shift
          validate_cli_title

          Xolo::Admin::Options.cli_cmd.version = ARGV.shift
          validate_cli_version if Xolo::Admin::Options.cli_cmd.version

        end # if
      end

      # Are we showing the full help? If so, re-parse the global opts
      def self.reparse_global_cli_for_help?
        cmdstr = Xolo::Admin::Options.cli_cmd.command.to_s
        return false unless cmdstr.empty? || cmdstr.start_with?(Xolo::DASH)

        ARGV.unshift '--help'
        parse_global_cli
        true
      end

      # parse the options for the command, if we aren't doing walkthru
      def self.parse_cmd_opts
        # set these for use inside the optimist options block
        cmd = Xolo::Admin::Options.cli_cmd.command
        return if cmd == Xolo::Admin::Options::HELP_CMD || cmd.to_s.empty?

        executable_file = Xolo::Admin.executable.basename
        cmd_desc = Xolo::Admin::Options::COMMANDS.dig cmd, :desc
        cmd_display = Xolo::Admin::Options::COMMANDS.dig cmd, :display
        cmd_opts = Xolo::Admin::Options::COMMANDS.dig cmd, :opts
        vers_cmd = version_command?
        title_or_vers_command = title_or_version_command?
        arg_banner = Xolo::Admin::Options::COMMANDS.dig(cmd, :arg_banner)
        arg_banner ||= Xolo::Admin::Options::DFT_CMD_TITLE_ARG_BANNER

        Optimist.options do
          # NOTE: extra newlines are added to the front of strings, cuz
          # optimist's 'banner' method chomps the ends.
          banner 'Command:'
          banner "  #{cmd}, #{cmd_desc}"

          banner "\nUsage:"
          banner "  #{executable_file} #{cmd_display} [options]"

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
              required = deets[:required] && Xolo::Admin::CommandLine.add_command?

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

      # CLI VALIDATION
      #
      # TODO: Move these to Xolo::Admin::Validate? or leave them here?
      #
      # They are validating the commandline itself, not the values being used
      # for the command opts.
      #######################################

      # is the given command valid?
      #########
      def self.validate_cli_command
        cmd = Xolo::Admin::Options.cli_cmd.command
        return if Xolo::Admin::Options::COMMANDS.key? cmd

        msg =
          if cmd.to_s.empty?
            "Usage: #{Xolo::Admin.usage}"
          else
            "Unknonwn command: #{cmd}"
          end
        raise ArgumentError, msg
      end # validate command

      # were we given a title?
      #########
      def self.validate_cli_title
        # this command doesn't need a title arg
        return if Xolo::Admin::Options::COMMANDS[Xolo::Admin::Options.cli_cmd.command][:target] == :none

        # TODO:
        #   If this is an 'add-' command, ensure the title
        #   doesn't already exist.
        #   Otherwise, make sure it does already exist, except for
        #   'search' which uses the CLI title as a search pattern.
        #
        title = Xolo::Admin::Options.cli_cmd.title
        raise ArgumentError, "No title provided!\nUsage: #{Xolo::Admin.usage}" unless title

        Xolo::Admin::Validate.title title # unless title.to_s.start_with?(Xolo::DASH)

        # return if title && !title.start_with?(Xolo::DASH)

        #  raise ArgumentError, "No title provided!\nUsage: #{Xolo::Admin.usage}"
      end

      # were we given a version?
      #########
      def self.validate_cli_version
        # this command doesn't need a version arg
        return if Xolo::Admin::Options::COMMANDS[Xolo::Admin::Options.cli_cmd.command][:target] == :none

        # TODO:
        #   If this is an 'add-' command, ensure the version
        #   doesn't already exist.
        #   Otherwise, make sure it does already exist
        #

        vers = Xolo::Admin::Options.cli_cmd.version
        return if vers && !vers.start_with?(Xolo::DASH)

        raise ArgumentError,
              "No version provided with '#{Xolo::Admin::Options.cli_cmd.command}' command!\nUsage: #{Xolo::Admin.usage}"
      end

      # @return [Boolean] does the command we're running deal with titles?
      ##########
      def self.title_command?
        Xolo::Admin::Options::COMMANDS[Xolo::Admin::Options.cli_cmd.command][:target] == :title
      end

      # @return [Boolean] does the command we're running deal with versions?
      ##########
      def self.version_command?
        Xolo::Admin::Options::COMMANDS[Xolo::Admin::Options.cli_cmd.command][:target] == :version
      end

      # @return [Boolean] does the command we're running deal with either titles or versions?
      ##########
      def self.title_or_version_command?
        Xolo::Admin::Options::COMMANDS[Xolo::Admin::Options.cli_cmd.command][:target] == :title_or_version
      end

      # @return [Boolean] does the command we're running add something (a title or version) to xolo?
      ##########
      def self.add_command?
        Xolo::Admin::Options::ADD_COMMANDS.include? Xolo::Admin::Options.cli_cmd.command
      end

    end # module CommandLine

  end # module Admin

end # module Xolo
