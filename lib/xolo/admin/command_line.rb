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

      def self.parse_cli
        executable_file = Xolo::Admin.executable.basename

        # deal with 'help', 'help help', 'help --help' and 'help -h'
        ARGV.unshift '--help' if ARGV[0] == Xolo::Admin::Options::HELP_CMD && [nil, '', 'help', '--help',
                                                                               '-h'].include?(ARGV[1])

        opts =
          Optimist.options do
            version Xolo::VERSION
            banner 'Usage:'
            banner "  #{Xolo::Admin.usage}\n\n"
            banner "\nGlobal Options:"

            opt :version, 'Print version and exit' ## add this here or it goes to bottom of help
            opt :help, 'Show this help and exit' ## add this here or it goes to bottom of help
            Xolo::Admin::Options::GLOBAL_OPTIONS.each do |opt_key, deets|
              opt opt_key, deets[:desc], short: deets[:cli]
            end
            stop_on Xolo::Admin::Options::SUB_COMMANDS.keys

            banner "\nCommands:"
            Xolo::Admin::Options::SUB_COMMANDS.each { |cmd, deets| banner format('  %-20s %s', cmd, deets[:desc]) }

            banner "\nExamples"
            banner "  #{executable_file} add-title google-chrome <options...>"
            banner "    Add a new title to Xolo with the title-id 'google-chrome',"
            banner '    specifying all options on the command line'

            banner "\n  #{executable_file} --walkthru add-title google-chrome <options...>"
            banner "    Add a new title to Xolo with the title-id 'google-chrome',"
            banner '    providing options interactively'

            banner "\n  #{executable_file} edit-title google-chrome <options...>"
            banner "    Edit the existing title with the title-id 'google-chrome',"
            banner '    specifying all options on the command line'

            banner "\n  #{executable_file} delete-title google-chrome"
            banner "    Delete the existing title with the title-id 'google-chrome'"

            banner "\n  #{executable_file} add-version google-chrome 95.144.21194 <options...>"
            banner "    Add a new version number 95.144.21194 to the title-id 'google-chrome'"
            banner '    specifying all options on the command line.'
            banner '    Options not provided are inherited from the previous version, if available.'

            banner "\n  #{executable_file} edit-version google-chrome 95.144.21194 <options...>"
            banner "    Edit version number 95.144.21194 of the title-id 'google-chrome'"
            banner '    specifying all options on the command line'

            banner "\n  #{executable_file} delete-version google-chrome 95.144.21194"
            banner "    Delete version 95.144.21194 from the title-id 'google-chrome'"

            banner "\n\nUse '#{executable_file} help command'  or '#{executable_file} command --help' to see command-specific help."
          end # Optimist.options

        Xolo::Admin::Options.global_opts = opts
        Xolo::Admin::Options.global_opts.command = ARGV.shift

        validate_command

        parse_command_cli
      end

      #
      #######
      def self.parse_command_cli
        executable_file = Xolo::Admin.executable.basename
        cmd =  Xolo::Admin::Options.global_opts.command

        if cmd == Xolo::Admin::Options::HELP_CMD
          Xolo::Admin::Options.global_opts.command = ARGV.shift
          cmd = Xolo::Admin::Options.global_opts.command
          validate_command
          ARGV.unshift '--help'
        end

        cmd_opts = Xolo::Admin::Options::SUB_COMMANDS[cmd][:opts]
        cmd_desc = Xolo::Admin::Options::SUB_COMMANDS[cmd][:desc]
        cmd_display = Xolo::Admin::Options::SUB_COMMANDS[cmd][:display]
        vers_cmd = version_command?

        opts =
          Optimist.options do
            banner "Command: #{cmd}, #{cmd_desc}"
            banner 'Usage: '
            banner "  #{executable_file} #{cmd_display} options\n\n"
            banner "\ntitle-id:     The unique name of this title in Xolo, e.g. 'google-chrome'"
            banner "version:      The version you are working with. e.g. '12.34.5'" if vers_cmd

            banner "\nOptions:"

            cmd_opts.each do |opt_key, deets|
              next unless deets[:sub_commands]&.include? cmd

              desc = deets[:desc]
              opt opt_key, desc, short: deets[:cli], type: deets[:type]
            end # opts_to_use.each
          end # Optimist.options

        Xolo::Admin::Options.cmd_opts = opts
        Xolo::Admin::Options.cmd_opts.title_id = ARGV.shift
        Xolo::Admin::Options.cmd_opts.version = ARGV.shift if vers_cmd
      end # parse_command_cli

      # is the given command valid?
      def self.validate_command
        cmd = Xolo::Admin::Options.global_opts.command
        return if Xolo::Admin::Options::SUB_COMMANDS.key? cmd

        msg =
          if cmd.to_s.empty?
            "Usage: #{Xolo::Admin.usage}"
          else
            "Unknonwn command: #{cmd}"
          end
        Optimist.die msg
      end # validate command

      # does the command we're running deal with versions? if not, just deals with titles
      def self.version_command?
        cmd = Xolo::Admin::Options.global_opts.command
        Xolo::Admin::Options::SUB_COMMANDS[cmd][:opts] == Xolo::Admin::Options::VERSION_OPTIONS
      end

    end # module CommandLine

  end # module Admin

end # module Xolo
