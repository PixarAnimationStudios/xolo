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

require 'optimist_with_insert_blanks'

module Xolo

  module Server

    # Module for parsing and validating the xadm options from the commandline
    module CommandLine

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # when this module is extended
      def self.extended(extender)
        Xolo.verbose_extend extender, self
      end

      #### Constants
      #########################

      CONFIG_CMD = 'config'

      SUBCOMMANDS = [CONFIG_CMD].freeze

      CLI_OPTIONS = {
        production: {
          label: 'Production',
          cli: :p,
          walkthru: false,
          desc: <<~ENDDESC
            Run xoloserver in production mode.
            This sets various server settings to production mode, including setting the log-level to 'info' at start-time, unless  -d is also given.

            By default the server starts in development mode, and the log level is 'debug'
          ENDDESC
        },

        debug: {
          label: 'Debug',
          cli: :d,
          walkthru: false,
          desc: <<~ENDDESC
            Run xoloserver in debug mode. This sets the log-level to 'debug' at start-time in production mode.
          ENDDESC
        }
      }.freeze

      # CLI usage message
      ################################################
      def usage
        @usage ||= "#{Xolo::Server::EXECUTABLE_FILENAME} --production --debug --help --version [config --help options args]"
      end

      # An OStruct to hold the CLI options
      ################################################
      def cli_opts
        @cli_opts ||= {}
      end

      # An OStruct to hold the config subcommand options
      ################################################
      def config_opts
        @config_opts ||= {}
      end

      # Use optimist to parse ARGV.
      ################################################
      def parse_cli
        # get the global options
        parse_global_opts
        return if ARGV.empty?

        # if there are subcommands, parse them
        subcommand = ARGV.shift
        case subcommand
        when CONFIG_CMD
          parse_config_opts
        else
          Optimist.die "Unknown subcommand: #{subcommand}"
        end
      end

      # Parse the main/global options
      ################################################
      def parse_global_opts
        usg = usage
        @cli_opts = Optimist.options do
          stop_on SUBCOMMANDS
          version "Xolo version: #{Xolo::VERSION}"
          synopsis <<~SYNOPSIS
            Name:
             #{Xolo::Server::EXECUTABLE_FILENAME}, The server for 'xolo', a tool for managing Patch Titles and Versions in Jamf Pro

            Usage:
              #{usg}

            See '#{Xolo::Server::EXECUTABLE_FILENAME} config --help' for configuration options.
          SYNOPSIS

          # add a blank line between each of the cli options in the help output
          # NOTE: chrisl added this to the optimist.rb included in this project.
          insert_blanks

          # The global opts
          ## manually set :version and :help here, or they appear at the bottom of the help
          opt :version, 'Print version and exit'
          opt :help, 'Show this help and exit'

          CLI_OPTIONS.each do |opt_key, deets|
            opt opt_key, deets[:desc], short: deets[:cli]
          end
        end # Optimist.options
      end

      # Parse the config subcommand options
      ################################################
      def parse_config_opts
        if ARGV.empty?
          config_opts[:show] = true
          return
        end

        @config_opts = Optimist.options do
          synopsis <<~ENDSYNOPSIS
            NAME
                #{Xolo::Server::EXECUTABLE_FILENAME} #{CONFIG_CMD} - Manage the server configuration file

            SYNOPSIS
                #{Xolo::Server::EXECUTABLE_FILENAME} #{CONFIG_CMD} [--show] [--expand] [config_key ...]

                #{Xolo::Server::EXECUTABLE_FILENAME} #{CONFIG_CMD} --set --config-key=value ...

                #{Xolo::Server::EXECUTABLE_FILENAME} #{CONFIG_CMD} --help


            DESCRIPTION
                The Xolo server configuration file is a YAML file located at
                  #{Xolo::Server.config.conf_file}"

                It contains a Ruby Hash of configuration options, the keys are Symbols and the values are the
                configuration values. While the file can be edited directly, it is recommended to use the
                'config' subcommand to view and set the values.

                Some sensitive values may be stored in the configuration file as a command or file path from
                which to read the actual value. Config values starting with a pipe '|' are executed as a command
                (after removing the pipe) and the value to be used is read from the standard output of the
                command. Values that are file paths are read from the file at the path. If the stored value
                doesn't start with a pipe, and is not a valid file path, the value is used as is. Be wary of
                security issues, permissions, etc when working with these values.

                See '#{Xolo::Server::EXECUTABLE_FILENAME} #{CONFIG_CMD} --help' for details on which configuration
                keys are used this way.

              Showing configuration values:
                When used without --set, --show is implied. If no config keys are given, all keys are shown.
                Keys can be given as 'key_name' or 'key-name'.

                Values are shown as stored in the config file. With --expand, the actual value used by the server
                is shown, after reading from commands or files.

              Setting configuration values:
                To set configuration values, use --set followed by one or more config keys as options, e.g.
                --config-key=value. You must restart the server to apply changes.

                NOTE: As of this writing, there is very little validation of the values you set, nor any
                enforcement of required values. Be careful.

              Help:
                Using --help shows this help message, and descriptions of all available config_keys as options
                to --set.

              Private values:
                Config keys marked Private (see #{Xolo::Server::EXECUTABLE_FILENAME} #{CONFIG_CMD} --help) are
                not shown when the config values are displayed to users of xadm, instead they see '#{Xolo::Server::Configuration::PRIVATE}'
          ENDSYNOPSIS

          # add a blank line between each of the cli options in the help output
          # NOTE: chrisl added this to the optimist.rb included in this project.
          insert_blanks

          opt :show, 'Show configuration values', short: :none
          opt :expand, 'Show expanded configuration values', short: :none
          opt :set, 'Set configuration values', short: :none

          Xolo::Server::Configuration::KEYS.each do |key, deets|
            # puts "defining: #{key} "

            moinfo = deets[:required] ? 'Required if not already set ' : ''
            moinfo = "#{moinfo}[Private]" if deets[:private]
            moinfo = "#{moinfo.strip}\n" unless moinfo.empty?

            desc = "#{moinfo}#{deets[:desc]}"
            opt key, desc, default: deets[:default], type: deets[:type], short: :none
          end # KEYS.each
        end # Optimist.options

        # any other args are the keys to display,
        # convert them to symbols and store them in the config_opts
        config_opts[:keys_to_display] = ARGV.map { |k| k.gsub('-', '_').to_sym } unless ARGV.empty?
      end

    end # module CommandLine

  end #  Server

end # module Xolo
