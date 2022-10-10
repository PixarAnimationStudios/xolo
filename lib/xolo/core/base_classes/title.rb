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
#

# frozen_string_literal: true

# main module
module Xolo

  module Core

    module BaseClasses

      # The base class for dealing with Titles in the
      # Xolo Server and the Admin modules.
      #
      # These are simpler objects than Windu::SoftwareTitle instances.
      # The Xolo server will translate between the two.
      #
      class Title

        # Constants
        #############################

        # These are the `xadm <command>` commands that deal with titles and their attributes/options.
        # The `delete-title` command only takes a title_id, and deletes it, no need
        # for any cli opts or walkthru.
        CLI_COMMANDS = [Xolo::Admin::Options::ADD_TITLE_CMD, Xolo::Admin::Options::EDIT_TITLE_CMD]

        # Attributes
        ######################

        # Attributes use of title titles.
        #
        # option settings
        #
        # - label: [String] to be displayed in admin interaction, walkthru, err msgs
        #    e.g. 'Title ID'
        #
        # - required: [Boolean] Must be provided when making a new title, cannot be
        #   deleted from existing titles.
        #
        # - cli: [false, Symbol] If false, this option is never taken as a cli
        #   option or walkthru menu choice, but may be used elsewhere,
        #   e.g. in this command:
        #      xadm edit-title my-title-id <options>
        #   'edit-title' is the subcommand and 'my-title-id' is the argument.
        #
        #   If a one-letter Symbol, this is the 'short' cli option, e.g. the Symbol :d
        #   defines the cli option '-d' which is used as the short option for --description
        #   NOTE: the long cli options are just the attrib keys preceded with -- and
        #   underscores converted to dashes, so :title_id becomes --title-id
        #
        #   If the symbol :none is used, there is no short variation of the CLI option.
        #
        # - type: [Symbol] the data type of the value. One of:
        #   :boolean, :integer, :string, :float, :io, :date.
        #   NOTE: Pluralizing those (except :boolean) means the value is an array of
        #   these objects
        #
        # - default: [String, Numeric, Boolean] the default value if nothing is
        #   provided. Note that titles never inherit values - only versions do.
        #
        # - validate: [Boolean, Symbol] how to validate values for this option.
        #   - If true (not just truthy) call method Xolo::Admin::Validate.<value_key>  e.g. Xolo::Admin::Validate.title_id(val)
        #   - If a Symbol, its a nonstandard method to call on the Xolo::Admin::Validate module
        #     e.g. :non_empty_array will validate the value using  Xolo::Admin::Validate.non_empty_array(val)
        #   - Anything else: no validation
        #
        # - invalid_msg: [String] custom message to display when invalid
        #
        # - immutable: [Boolean] This value can only be set when created a new title.
        #   When editing an existing title, it cannot be changed.
        #
        # - desc: [String] helpful text explaining what the option means. Displayed
        #   during walkthru, in help messages, and in some err messages.
        #
        # - sub_commands: [Array<String>] the subcommands that will take this option
        #
        ATTRIBUTES = {

          title_id: {
            label: 'Title ID',
            required: true,
            cli: false,
            type: :string,
            immutable: true,
            walkthru: false,
            validate: true,
            sub_commands: [], # no subcommants take the title id - its always the arg of a subcommand
            invalid_msg: 'Not a valid title id! Must be lowercase alphanumeric and dashes only, cannot already exist in Xolo.',
            desc: <<~ENDDESC
              A unique string identifying this Software Title, e.g. 'folio'.
              The same as a 'basename' in d3.
              Must contain only lowercase letters, numbers, and dashes.
            ENDDESC
          },

          display_name: {
            label: 'Display Name',
            required: true,
            cli: :n,
            type: :string,
            validate: :title_display_name,
            invalid_msg: '"Not a valid display name, must be at least three characters, starting and ending with non-whitespace.',
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              A human-friendly name for the Software Title, e.g. 'Google Chrome', or
              'NFS Menubar'. Must be at least three characters long.
            ENDDESC
          },

          description: {
            label: 'Description',
            required: true,
            cli: :d,
            type: :string,
            validate: :title_desc,
            invalid_msg: "Not a valid description name, must be at least 20 characters. Include a useful dscription of what the software does,  URLs, developer names, etc. DO NOT USE, e.g. 'Installs Google Chrome' for the title 'google-chrome', that just wastes everyone's time.",
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              A useful dscription of what the software installed by this title does,
              You can also include URLs, developer names, support info, etc.
              DO NOT use, e.g. 'Installs Google Chrome' for the title 'GoogleChrome',
              that just wastes everyone's time. Must be at least 20 Characters.
            ENDDESC
          },

          publisher: {
            label: 'Publisher',
            required: true,
            cli: :p,
            type: :string,
            validate: true,
            invalid_msg: '"Not a valid Publisher, must be at least three characters.',
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              The company or entity that publishes this title, e.g. 'Apple, Inc.'
              or 'Pixar Animation Studios'.
            ENDDESC
          },

          app_bundle_id: {
            label: 'The bundle ID of the .app',
            required: true,
            validate: true,
            type: :string,
            invalid_msg: '"Not a valid bundle ID, must include at least one dot.',
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              If this title installs a .app bundle, the app's bundle-id must be provided.
              This is found in the CFBundleIdentifier key of the app's Info.plist.
              e.g. 'com.google.chrome'
              If the title does not install a .app bundle, leave this blank
            ENDDESC
          },

          app_name: {
            label: 'The name of the .app',
            required: true,
            validate: true,
            type: :string,
            invalid_msg: "Not a valid App name, must end with '.app'",
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              If this title installs a .app bundle, the app's name must be provided.
              This the name of the bundle iteslf on disk, e.g. 'Google Chrome.app'.
              If the title does not install a .app bundle, leave this blank
            ENDDESC
          },

          targets: {
            label: 'Target Computer Groups',
            default: NONE,
            validate: :jamf_group,
            type: :strings,
            invalid_msg: "Invalid target. Targets must be existing Jamf Computer Groups, '#{TARGET_ALL}', or '#{NONE}'.",
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              A comma-separated list of Jamf Computer Groups identifying computers
              that will automatically have this title installed. Use 'all' to auto-
              install on all computers (except those that are excluded).
            ENDDESC
          },

          exclusions: {
            label: 'Excluded Computer Groups',
            validate: :jamf_group,
            default: NONE,
            type: :strings,
            invalid_msg: "Invalid exclusion. All exclusions must be an existing Jamf Computer Group,  or '#{NONE}'.",
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              A comma-separated list of Jamf Computer Groups identifying computers
              that will not be able to install this, unless forced. If a computer is
              in both the targets and the exclusions, the exclusion wins.
            ENDDESC
          },

          expiration: {
            label: 'Expire After Days',
            default: 0,
            validate: /\A\d+\z/,
            type: :integer,
            invalid_msg: 'Invalid expiration period. Must be a non-negative integer number of days. 0 for no expiration.',
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              If the all of the executables listed in 'Expiration Paths' have not been
              used in this number of days, the title is uninstalled from the computer.
            ENDDESC
          },

          expiration_paths: {
            label: 'Expiration Paths',
            validate: true,
            type: :strings,
            invalid_msg: "Invalid expiration paths. Must at least one absolute path starting with a '/' and containing at least one more non-adjacent '/'.",
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              Paths to executables that must come to the foreground of a user's GUI session
              to be considered 'usage' of this title.
            ENDDESC
          },

          self_service: {
            label: 'Show in Self Service',
            validate: true,
            type: :boolean,
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              Should this title be available in Self Service?
              If so, and there are defined target groups, will only be
              available to non-excluded computers in those groups.
              Self Service is not available for titles with the target 'all'.
            ENDDESC
          },

          self_service_category: {
            label: 'Self Service Category',
            validate: true,
            type: :string,
            sub_commands: CLI_COMMANDS,
            invalid_msg: 'Invalid category. Must exist in Jamf Pro.',
            desc: <<~ENDDESC
              The Category in which to display this title in Self Service
            ENDDESC
          },

          self_service_icon: {
            label: 'Self Service Icon',
            validate: true,
            type: :string,
            invalid_msg: 'Invalid Icon Path. No such file found locally.',
            sub_commands: CLI_COMMANDS,
            desc: <<~ENDDESC
              Path to a local image file to use as the icon for this title in Self Service.
            ENDDESC
          },

          created_by: {
            label: 'Created By',
            type: :string,
            cli: false,
            walkthru: false,
            desc: <<~ENDDESC
              The login of the admin who created this title.
            ENDDESC
          },

          creation_date: {
            label: 'Creation Date',
            type: :date,
            cli: false,
            walkthru: false,
            desc: <<~ENDDESC
              The date this title was created.
            ENDDESC
          },

          modified_by: {
            label: 'Modified By',
            type: :string,
            cli: false,
            walkthru: false,
            desc: <<~ENDDESC
              The login of the admin who last modified this title.
            ENDDESC
          },

          modification_date: {
            label: 'Creation Date',
            type: :date,
            cli: false,
            walkthru: false,
            desc: <<~ENDDESC
              The date this title was last modified.
            ENDDESC
          }

        }.freeze

        ATTRIBUTES.keys.each do |attr|
          attr_accessor attr
          attr_accessor "new_#{attr}"
        end

        # Constructor
        ######################
        def initialize(data_hash)
          data_hash.each { |k, v| instance_variable_set "@#{k}", v }
        end

      end # class Title

    end # module BaseClasses

  end # module Core

end # module Xolo
