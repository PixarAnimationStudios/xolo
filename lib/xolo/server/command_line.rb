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

require 'ostruct'
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
            This sets various server settings to production mode, including
            setting the log-level to 'info' at start-time, unless  -d is also given.

            By default the server starts in development mode, and the log level is 'debug'
          ENDDESC
        },

        debug: {
          label: 'Debug',
          cli: :d,
          walkthru: false,
          desc: <<~ENDDESC
            Run xoloserver in debug mode
            This sets the log-level to 'debug' at start-time in production mode.
          ENDDESC
        } # ,

        # show_config: {
        #   label: 'Show Config',
        #   cli: :s,
        #   walkthru: false,
        #   desc: <<~ENDDESC
        #     Show the current configuration values.
        #   ENDDESC
        # },

        # config_help: {
        #   label: 'Debug',
        #   cli: :C,
        #   walkthru: false,
        #   desc: <<~ENDDESC
        #     Show the available configuration keys and their descriptions.
        #   ENDDESC
        # },

        # config: {
        #   label: 'Config',
        #   cli: :c,
        #   walkthru: false,
        #   desc: <<~ENDDESC
        #     Set a configuration key to a value.
        #     Usage: xoloserver --config key=value
        #     To see the available keys and their descriptions, use the --config-help option.
        #   ENDDESC
        # }
      }.freeze

      # CLI usage message
      def usage
        @usage ||= "#{Xolo::Server::EXECUTABLE_FILENAME} [--production --debug]"
      end

      # An OStruct to hold the CLI options
      def cli_opts
        @cli_opts ||= OpenStruct.new
      end

      # An OStruct to hold the config subcommand options
      def config_opts
        @config_opts ||= OpenStruct.new
      end

      # Use optimist to parse ARGV.
      ################################################
      def parse_cli
        parsed_opts = parse_global_opts

        # save the global opts hash from optimist into our OpenStruct
        parsed_opts.each { |k, v| cli_opts[k] = v }

        # if there are subcommands, parse them
        return if ARGV.empty?

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
        Optimist.options do
          stop_on SUBCOMMANDS

          banner 'Name:'
          banner "  #{Xolo::Server::EXECUTABLE_FILENAME}, The server for 'xolo', a tool for managing Software Titles and Versions in Jamf Pro."

          banner "\nUsage:"
          banner "  #{usage}"

          banner "\nOptions:"

          # add a blank line between each of the cli options in the help output
          # NOTE: chrisl added this to the optimist.rb included in this project.
          insert_blanks

          version Xolo::VERSION

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

        parsed_config_opts = Optimist.options do
          synopsis <<~SYNOPSIS
            Xolo Server Configuration
            #################################

            The Xolo server configuration file is a YAML file located at
              #{Xolo::Server.config.conf_file}"
            It contains a Ruby Hash of configuration options, the keys are Symbols and the values are the configuration values.

            Usage:
              #{Xolo::Server::EXECUTABLE_FILENAME} #{CONFIG_CMD} [config_key ... | --config-key=value ... | --help]"

            With no options or args, show the current configuration as stored in the config file.

            With any config keys as arguments, e.g. 'key_name', show the value(s) after the server loads the config.
            For some keys, the config file contains a command or file path from which to read the actual value.
            Use this to see the actual value used by the server. E.g. if the file's jamf_api_pw key contains
            '|/path/to/secrets/tool jamf-pw', this will display the value used: 'PassWd4jamf-pw'

            With config keys as options, update config file, setting specified key to the value.
            You must restart the server to apply changes.
            NOTE: keys with the form key_name are set with --key-name

            Notes:
            Those marked Private (see #{Xolo::Server::EXECUTABLE_FILENAME} #{CONFIG_CMD} --help) are not shown when the
            config values are displayed to users of xadm, instead they see '#{Xolo::Server::Configuration::PRIVATE}'
          SYNOPSIS

          # add a blank line between each of the cli options in the help output
          # NOTE: chrisl added this to the optimist.rb included in this project.
          insert_blanks

          Xolo::Server::Configuration::KEYS.each do |key, deets|
            # puts "defining: #{key} "

            moinfo = deets[:required] ? 'Required if not already set ' : ''
            moinfo = "#{moinfo}[Private]" if deets[:private]
            moinfo = "#{moinfo.strip}\n" unless moinfo.empty?

            desc = "#{moinfo}#{deets[:desc]}"
            opt key, desc, default: deets[:default], type: deets[:type], short: :none
          end # KEYS.each
        end # Optimist.options

        # save the global opts hash from optimist into our OpenStruct
        parsed_config_opts.each { |k, v| config_opts[k] = v }
      end

    end # module CommandLine

  end #  Server

end # module Xolo
