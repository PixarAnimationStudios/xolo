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
        },

        show_config: {
          label: 'Show Config',
          cli: :c,
          walkthru: false,
          desc: <<~ENDDESC
            Show the current configuration values and exit.
          ENDDESC
        },

        config_help: {
          label: 'Debug',
          cli: :C,
          walkthru: false,
          desc: <<~ENDDESC
            Show the available configuration keys and their descriptions.
          ENDDESC
        }
      }.freeze

      # CLI usage message
      def usage
        @usage ||= "#{Xolo::Server::EXECUTABLE_FILENAME} [--production --debug]"
      end

      # An OStruct to hold the CLI options
      def cli_opts
        @cli_opts ||= OpenStruct.new
      end

      # Use optimist to parse ARGV.
      ################################################
      def parse_cli
        parsed_opts = Optimist.options do
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

        # save the global opts hash from optimist into our OpenStruct
        parsed_opts.each { |k, v| cli_opts[k] = v }
      end

    end # module CommandLine

  end #  Server

end # module Xolo
