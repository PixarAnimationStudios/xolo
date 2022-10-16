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

      # These commands get their opts from the Title Attributes
      TITLE_OPT_COMMANDS = [ADD_TITLE_CMD, EDIT_TITLE_CMD]

      # These commands get their opts from the Version Attributes
      VERSION_OPT_COMMANDS = [ADD_VERSION_CMD, EDIT_VERSION_CMD]

      COMMANDS = {
        ADD_TITLE_CMD => {
          desc: 'Add a new software title',
          display: "#{ADD_TITLE_CMD} title-id",
          opts: Xolo::Core::BaseClasses::Title::ATTRIBUTES
        },

        EDIT_TITLE_CMD => {
          desc: 'Edit an exising software title',
          display: "#{EDIT_TITLE_CMD} title-id",
          opts: Xolo::Core::BaseClasses::Title::ATTRIBUTES
        },

        DELETE_TITLE_CMD => {
          desc: 'Delete a software title, and all of its versions',
          display: "#{DELETE_TITLE_CMD} title-id",
          opts: {}
        },

        ADD_VERSION_CMD => {
          desc: 'Add a new version to a title',
          display: "#{ADD_VERSION_CMD} title-id version",
          opts: Xolo::Core::BaseClasses::Version::ATTRIBUTES
        },

        EDIT_VERSION_CMD => {
          desc: 'Edit a version of a title',
          display: "#{EDIT_VERSION_CMD} title-id version",
          opts: Xolo::Core::BaseClasses::Version::ATTRIBUTES
        },

        RELEASE_VERSION_CMD => {
          desc: 'Release a version to all targets.',
          display: "#{DELETE_VERSION_CMD} title-id version",
          opts: {}
        },

        DELETE_VERSION_CMD => {
          desc: 'Delete a version from a title.',
          display: "#{DELETE_VERSION_CMD} title-id version",
          opts: {}
        },

        SEARCH_CMD => {
          desc: 'Search for titles in Xolo.',
          display: "#{SEARCH_CMD} title-id",
          opts: {}
        },

        REPORT_CMD => {
          desc: 'Report installation data.',
          display: "#{REPORT_CMD} title-id [version]",
          opts: {}
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

      def self.cmd_args
        @cmd_args ||= OpenStruct.new
      end

      #####
      def self.required_title_values
        @required_title_values ||= Xolo::Core::BaseClasses::Title::ATTRIBUTES.select { |_k, v| v[:required] }
      end

    end # module Options

  end # module Admin

end # module Xolo
