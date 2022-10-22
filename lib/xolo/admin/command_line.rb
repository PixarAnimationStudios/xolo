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

require 'optimist'

module Xolo

  module Admin

    # Module for parsing and validating the xadm options from the commandline
    module CommandLine

      # Use optimist to parse ARGV.
      # This will handle the global opts and the xadm command,
      # populating Xolo::Admin::Options.global_opts, and Xolo::Admin::Options.cli_cmd
      ################################################
      def self.parse_cli
        # deal with 'help', 'help help', 'help --help' and 'help -h'
        ARGV.unshift '--help' if ARGV[0] == Xolo::Admin::Options::HELP_CMD && [nil, '', 'help', '--help',
                                                                               '-h'].include?(ARGV[1])

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

          # add a blank line between each of the cli options
          # NOTE: chrisl added this to the optimist.rb included in this project.
          insert_blanks

          version Xolo::VERSION

          # The global opts
          opt :version, 'Print version and exit' ## add this here or it goes to bottom of help
          opt :help, 'Show this help and exit' ## add this here or it goes to bottom of help
          Xolo::Admin::Options::GLOBAL_OPTIONS.each do |opt_key, deets|
            opt opt_key, deets[:desc], short: deets[:cli]
          end
          stop_on Xolo::Admin::Options::COMMANDS.keys

          banner "\nCommands:"
          Xolo::Admin::Options::COMMANDS.each do |cmd, deets|
            banner format('  %-20s %s', cmd, deets[:desc])
          end

          banner "\nCommand Arguments:"
          banner "  title:     The unique name of a title in Xolo, e.g. 'google-chrome'"
          banner "  version:   The version you are working with, if applicable, e.g. '12.34.5'"

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
      # This gets the title, and if needed the version, storing them in
      # Xolo::Admin::Options.cli_cmds
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

        # validate them individually
        begin
          Xolo::Admin::Validate.cli_cmd_opts
        rescue Xolo::InvalidDataError => e
          Optimist.die e.to_s
        end

        # add in current_opt_values for anything not given on the cli
        Xolo::Admin::Options.current_opt_values.each do |k, v|
          next if Xolo::Admin::Options.cli_cmd_opts["#{k}_given"]

          Xolo::Admin::Options.cli_cmd_opts[k] = v if v
        end

        # now Xolo::Admin::Options.cli_cmd_opts contains all the data for
        # processing whatever we're processing, so do the internal consistency check
        begin
          Xolo::Admin::Validate.internal_consistency Xolo::Admin::Options.cli_cmd_opts
        rescue Xolo::InvalidDataError => e
          Optimist.die e.to_s
        end

        # If we got here, everything in Xolo::Admin::Options.cli_cmd_opts is good to go
        # and can be sent to the server for processing.
      end # parse_command_cli

      # Get the xadm command, and its args (title, and maybe version)
      # from the Command Line. They get stored in
      # Xolo::Admin::Options.cli_cmd
      def self.parse_cmd_and_args
        # next item will be the command we are executing
        Xolo::Admin::Options.cli_cmd.command = ARGV.shift
        validate_cli_command

        # if the command is 'help'
        # then
        #   'xadm help command'
        # becomes
        #   'xadm command --help'
        #
        if Xolo::Admin::Options.cli_cmd.command == Xolo::Admin::Options::HELP_CMD
          Xolo::Admin::Options.cli_cmd, command = ARGV.shift
          validate_cli_command
          ARGV.unshift '--help'

        # Otherwise, the command is not 'help', so the next item
        # on the command line is the title we are working with
        else
          Xolo::Admin::Options.cli_cmd.title = ARGV.shift
          validate_cli_title

          # and if the command we are running is a 'version' command,
          # the next item is the version we are working with
          if version_command?
            Xolo::Admin::Options.cli_cmd.version = ARGV.shift
            validate_cli_version
          end
        end
      end

      # parse the options for the command, if we aren't doing walkthru
      def self.parse_cmd_opts
        # set these for use inside the optimist options block
        cmd = Xolo::Admin::Options.cli_cmd.command
        executable_file = Xolo::Admin.executable.basename
        cmd_opts = Xolo::Admin::Options::COMMANDS[cmd][:opts]
        cmd_desc = Xolo::Admin::Options::COMMANDS[cmd][:desc]
        cmd_display = Xolo::Admin::Options::COMMANDS[cmd][:display]
        vers_cmd = version_command?

        Optimist.options do
          # NOTE: extra newlines are added to the front of strings, cuz
          # optimist's 'banner' method chomps the ends.
          banner 'Command:'
          banner "  #{cmd}, #{cmd_desc}"

          banner "\nUsage:"
          banner "  #{executable_file} #{cmd_display} options"

          banner "\nArguments:"
          banner "  title:     The unique name of this title in Xolo, e.g. 'google-chrome'"
          banner "  version:      The version you are working with. e.g. '12.34.5'" if vers_cmd

          banner "\nOptions:"

          # add a blank line between each of the cli options
          # NOTE: chrisl added this to the optimist.rb included in this project.
          insert_blanks

          # for each cmd opt that has deets[:depends]
          # we'll create a line 'depends: opt_key, deets[:depends]'
          dependants = []

          # for each cmd opt that has deets[:conflicts] (an array of conflicting
          # cli opt keys)  we'll create a line 'conflicts: opt_key, opt_key'
          conflicts = []

          # create the optimist options for the command
          cmd_opts.each do |opt_key, deets|
            next unless deets[:cli]

            # TODO: stop using optimist for required cli opts
            # and use the internal-consistencey validation, which
            # applies to both CLI and walk thru.
            required = deets[:required] && Xolo::Admin::CommandLine.add_command?

            desc = deets[:desc]
            desc = "#{desc}REQUIRED" if required

            # TODO: should these only be used for add_commands?
            # or checked later when validating all the opts together?
            # Prob the latter, so the same issues can be checked via walkthru
            # and while editing.
            # dependants << [opt_key, deets[:depends]] if deets[:depends]
            # conflicts << [opt_key, deets[:conflicts]] if deets[:conflicts]

            # deets[:conflicts].each { |c| conflicts << [opt_key, c] } if deets[:conflicts]

            # booleans are CLI flags defaulting to false
            # everything else is a string that we will convert as we validate later
            type = deets[:type] == :boolean ? :boolean : :string

            # here we actually set the optimist opt.
            opt opt_key, desc, short: deets[:cli], type: type, required: required, multi: deets[:multi]
          end # opts_to_use.each

          # set any option conflicts
          # unless conflicts.empty?
          #   conflicts.each do |pair|
          #     conflicts pair.first, pair.last
          #   end
          # end

          # set any option dependencies
          # unless dependants.empty?
          #   dependants.each do |pair|
          #     depends pair.first, pair.last
          #   end
          # end
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
        Optimist.die msg
      end # validate command

      # were we given a title?
      #########
      def self.validate_cli_title
        # TODO:
        #   If this is an 'add-' command, ensure the title
        #   doesn't already exist.
        #   Otherwise, make sure it does already exist, except for
        #   'search' which uses the CLI title as a search pattern.
        #
        tid = Xolo::Admin::Options.cli_cmd.title

        Xolo::Admin::Validate.title tid

        return if tid && !tid.start_with?(Xolo::DASH)

        Optimist.die  "No title provided!\nUsage: #{Xolo::Admin.usage}"
      end

      # were we given a version?
      #########
      def self.validate_cli_version
        # TODO:
        #   If this is an 'add-' command, ensure the version
        #   doesn't already exist.
        #   Otherwise, make sure it does already exist
        #

        vers = Xolo::Admin::Options.cli_cmd.version
        return if vers && !vers.start_with?(Xolo::DASH)

        Optimist.die "No version provided with '#{Xolo::Admin::Options.cli_cmd.command}' command!\nUsage: #{Xolo::Admin.usage}"
      end

      # does the command we're running deal with versions?
      # if not, it deals with titles
      ##########
      def self.version_command?
        Xolo::Admin::Options::COMMANDS[Xolo::Admin::Options.cli_cmd.command][:target] == :version
      end

      # does the command we're running add something (a title or version) to xolo?
      ##########
      def self.add_command?
        Xolo::Admin::Options::ADD_COMMANDS.include? Xolo::Admin::Options.cli_cmd.command
      end

    end # module CommandLine

  end # module Admin

end # module Xolo
