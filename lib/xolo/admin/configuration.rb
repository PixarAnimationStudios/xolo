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
#

# frozen_string_literal: true

# main module
module Xolo

  module Admin

    # Personal prefs for users of 'xadm'
    class Configuration < Xolo::Core::BaseClasses::Configuration

      include Singleton

      # Save to yaml file in ~/Library/Preferences/com.pixar.xolo.admin.prefs.yaml
      #
      # - hostname of xolo server
      #   - always port 443, for now
      #
      # Note - credentials for Xolo Server area stored in login keychain.
      # code for that is in the Xolo::Admin::Credentials module.

      # Constants
      ##############################
      ##############################
      CONF_FILE_DIR = '~/Library/Preferences/'
      CONF_FILENAME = 'com.pixar.xolo.admin.config.yaml'

      CREDENTIALS_NEEDED = '<credentials needed>'
      CREDENTIALS_IN_KEYCHAIN = '<stored in keychain>'
      CREDENTIALS_STORED = '<stored>'

      # See Xolo::Core::BaseClasses::Configuration for required values
      # when used to access the config file.
      #
      # Also adds values used for CLI and walktru, as with the
      # ATTRIBUTES of Xolo::Core::BaseClasses::Title and Xolo::Core::BaseClasses::Version
      #
      KEYS = {

        # @!attribute hostname
        #   @return [String]
        hostname: {
          required: true,
          label: 'Hostname',
          type: :string,
          validate: true,
          invalid_msg: "Invalid hostname, can't connect, or not a Xolo server.",
          desc: <<~ENDDESC
            The hostname of the Xolo Server to interact with,
            e.g. 'xolo.myschool.edu'
            Enter 'x' to exit.
          ENDDESC
        },

        # @!attribute pw
        #   @return [String]
        no_gui: {
          required: false,
          label: 'Non-GUI mode',
          type: :boolean,
          validate: :validate_boolean,
          walkthru_na: :pw_na,
          secure_interactive_input: true,
          desc: <<~ENDDESC
            If you are configuring xadm for a non-GUI environment, such as a CI workflow,
            set this to true. This will prevent xadm from trying to access the keychain.

            The password value can then be set to:
            - A command prefixed with '|' that will be executed to get the password from stdout,
            - A path to a readable file containing the password,
            - Or the password itself, which will be stored in the xadm config file
          ENDDESC
        },

        # @!attribute admin
        #   @return [String]
        admin: {
          required: true,
          label: 'Username',
          type: :string,
          validate: false,
          desc: <<~ENDDESC
            The Xolo admin username for connecting to the Xolo server.
            The same that you would use to connect to Jamf Pro.
          ENDDESC
        },

        # @!attribute pw
        #   @return [String]
        pw: {
          required: true,
          label: 'Password',
          type: :string,
          validate: true,
          walkthru_na: :pw_na,
          secure_interactive_input: true,
          invalid_msg: 'Incorrect username or password, or user not allowed.',
          desc: <<~ENDDESC
            The password for connecting to the Xolo server. The same that
            you would use to connect to Jamf Pro.
            It will be stored in your login keychain for use in your terminal or
            other MacOS GUI applications, such as XCode.

            If you are configuring a non-GUI environment, such as a CI workflow,
            set 'Non-GUI mode' to true.

            In that case, if you start this value with a vertical bar '|', everything
            after the bar is a command that will be executed to get the password from stdout.
            This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used.

            Otherwise the password is stored directly in the xadm config file.

            Enter 'x' to exit if you are in an unknown password loop.
          ENDDESC
        },

        # @!attribute pw
        #   @return [String]
        editor: {
          label: 'Preferred editor',
          type: :string,
          validate: true,
          invalid_msg: 'That editor does not exist, or is not executable.',
          desc: <<~ENDDESC
            The editor to use for editing descriptions and other multi-line
            text. Enter the full path to an editor, such as '/usr/bin/vim'. It must
            take the name of a file to edit as its only argument.
            You can provide command line options to the editor, such as, such as
            the -w option for the GUI editor /usr/local/bin/bbedit, which is needed so that
            the cli tool waits for the editor to finish before continuing.
            If not set in your config, you will be asked to use one of a few basic ones.
          ENDDESC
        }

      }.freeze

      # Class methods
      ##############################
      ##############################

      # The KEYS that are available as CLI & walkthru options
      # with the 'xadm config' command.
      #
      # @return [Hash{Symbol: Hash}]
      #
      ####################
      def self.cli_opts
        KEYS
      end

      # Public Instance methods
      ##############################
      ##############################

      # @return [Pathname] The file that stores configuration values
      #######################
      def conf_file
        @conf_file ||= Pathname.new("#{CONF_FILE_DIR}#{CONF_FILENAME}").expand_path
      end

    end # class Configuration

  end # module Admin

end # module Xolo
