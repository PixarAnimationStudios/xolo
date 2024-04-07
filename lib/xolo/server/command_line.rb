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

      #### Constants
      #########################

      CLI_OPTIONS = {
        data_dir: {
          label: 'Data Directory',
          cli: :d,
          desc: <<~ENDDESC
            The directory where xoloserver stores all its files.
            Defaults to #{Xolo::Server::DATA_DIR}
          ENDDESC
        },

        config_file: {
          label: 'Config File',
          cli: :c,
          desc: <<~ENDDESC
            The path to the config file for xoloserver.
            Detaults to #{Xolo::Server::CONF_FILE}
          ENDDESC
        },

        debug: {
          label: 'Debug',
          cli: :D,
          walkthru: false,
          desc: <<~ENDDESC
            Run xoloserver in debug mode
            This sets the log-level to 'debug' at start-time.
          ENDDESC
        }
      }.freeze

      # CLI usage message
      def self.usage
        @usage ||= "#{executable.basename} [--data-dir /path/to/nonstd/data/dir --config-file /path/to/alt/configfile.yaml --debug"
      end

      # An OStruct to hold the CLI options
      def self.cli_opts
        @cli_opts ||= OpenStruct.new
      end

      # Use optimist to parse ARGV.
      ################################################
      def self.parse_cli
        parsed_opts = Optimist.options do
          banner 'Name:'
          banner "  #{Xolo::Server.executable.basename}, The server for 'xolo', a tool for managing Software Titles and Versions in Jamf Pro."

          banner "\nUsage:"
          banner "  #{Xolo::Server.usage}"

          banner "\nOptions:"

          # add a blank line between each of the cli options in the help output
          # NOTE: chrisl added this to the optimist.rb included in this project.
          insert_blanks

          version Xolo::VERSION

          # The global opts
          ## manually set :version and :help here, or they appear at the bottom of the help
          opt :version, 'Print version and exit'
          opt :help, 'Show this help and exit'

          Xolo::Server::CLI_OPTIONS.each do |opt_key, deets|
            opt opt_key, deets[:desc], short: deets[:cli]
          end

        end # Optimist.options

        # save the global opts hash from optimist into our OpenStruct
        parsed_opts.each { |k, v| cli_opts[k] = v }
      end


    end # module CommandLine

  end # module Server

end # module Xolo
