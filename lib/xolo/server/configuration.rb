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

require 'singleton'
require 'ostruct'

module Xolo

  module Server

    # A class for working with pre-defined settings & preferences for Xolo
    #
    # This is a singleton class, only one instance can exist at a time.
    #
    # When the module loads, that instance is created, and is used to provide configuration
    # values throughout Xolo. It can be accessed via Xolo.config in applications.
    #
    # @note Many values in Xolo will also have a hard-coded default, if not defined
    # in the configuration.
    #
    # When the Xolo::Server::Configuration instance is created, the {GLOBAL_CONF} file (/etc/xolo.conf)
    # is examined if it exists, and the items in it are loaded into the attributes.
    #
    # Then the user-specific {USER_CONF} file (~/.xolo.conf) is examined if it exists, and
    # any attributes defined there will override those values from the {GLOBAL_CONF}.
    #
    # The file format is one attribute per line, thus:
    #   attr_name: value
    #
    # Lines that don't start with a known attribute name followed by a colon are ignored.
    # If an attribute is defined more than once, the last one wins.
    #
    # See {CONF_KEYS} for the available attributes, and how they are converted to the appropriate
    # Ruby class when loaded.
    #
    # At any point, the attributes can read or ne changed using standard Ruby getter/setter methods
    # matching the name of the attribute,
    # e.g.
    #
    #   # read the current title_editor_server_name configuration value
    #   Xolo.config.title_editor_server_name  # => 'foobar.appcatalog.jamfcloud.com'
    #
    #   # sets the title_editor_server_name to a new value
    #   Xolo.config.title_editor_server_name = 'baz.appcatalog.jamfcloud.com'
    #
    #
    # The current settings may be saved to the CONF_FILEe, or an arbitrary
    # file using {#save}.  The argument to {#save} should be either :user, :global, or a String or
    # Pathname file path.
    # NOTE: This overwrites any existing file with the current values of the Configuration object.
    #
    # To re-load the configuration use {#reload}. This clears the current settings, and re-reads
    # both the global and user files. If a pathname is provided, e.g.
    #   Xolo.config.reload '/path/to/other/file'
    # the current settings are cleared and reloaded from that other file.
    #
    # To view the current settings, use {#print}.
    #
    class Configuration

      include Singleton

      # Constants
      #####################################

      # Default Values
      ##########

      CONF_FILENAME = 'config.yaml'
      CONF_FILE = Xolo::Server::DATA_DIR + CONF_FILENAME

      SSL_DIR = Xolo::Server::DATA_DIR + 'ssl'
      SSL_CERT_FILENAME = 'cert.pem'
      SSL_KEY_FILENAME = 'key.pem'
      SSL_CERT_FILE = SSL_DIR + SSL_CERT_FILENAME
      SSL_KEY_FILE = SSL_DIR + SSL_KEY_FILENAME

      DFT_SSL_VERIFY = true

      DFT_LOG_DAYS_TO_KEEP = 14

      DFT_PKG_SIGNING_KEYCHAIN_FILENAME = 'xolo-pkg-signing.keychain-db'

      PIPE = '|'

      # Attributes
      #####################################

      # The attribute keys we maintain, and their default values
      ATTRIBUTES = {

        # @!attribute ssl_cert
        #   @return [String]
        ssl_cert: {
          default: nil,
          required: true,
          load_method: :data_from_command_file_or_string,
          desc: <<~ENDDESC
            The SSL Certificate for the https server in .pem format.
            When the server starts, it will be read from here, and stored in
            #{SSL_CERT_FILE}

            If you start this value with a vertical bar '|', everything after the bar
            is a command to be executed by the server at start-time. The command must
            return the certificate to standard output.
            This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used

            Otherwise the value is used as the certificate.

            Be careful of security concerns when certificates are stored in files.
          ENDDESC
        },

        # @!attribute ssl_key
        #   @return [String]
        ssl_key: {
          default: nil,
          required: true,
          load_method: :data_from_command_file_or_string,
          desc: <<~ENDDESC
            The private key for the SSL Certificate in .pem format.
            When the server starts, it will be read from here, and stored in
            #{SSL_KEY_FILE}

            If you start this value with a vertical bar '|', everything after the bar
            is a command to be executed by the server at start-time. The command must
            return the password to standard output.
            This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used

            Otherwise the value is used as the key.

            Be careful of security concerns when keys are stored in files.
          ENDDESC
        },

        # @!attribute ssl_verify
        #   @return [Boolean]
        ssl_verify: {
          default: DFT_SSL_VERIFY,
          desc: <<~ENDDESC
            Should the server verify the SSL certificates of machines it communicates with?
            Default is #{DFT_SSL_VERIFY}
          ENDDESC
        },

        # @!attribute log_days_to_keep
        #   @return [Integer]
        log_days_to_keep: {
          default: DFT_LOG_DAYS_TO_KEEP,
          desc: <<~ENDDESC
            The server log is rotated daily. How many days of log files should be kept?
            All logs are kept in the 'logs' directory inside the server's data directory.
            Default is #{DFT_LOG_DAYS_TO_KEEP}
          ENDDESC
        },

        # @!attribute pkg_signing_keychain
        #   @return [String]
        pkg_signing_keychain: {
          default: nil,
          required: true,
          desc: <<~ENDDESC
            The path to a macOS Keychain file containing the package-signing certificate used
            to sign pkgs as needed.

            They keychain will be copied to #{DFT_PKG_SIGNING_KEYCHAIN_FILENAME} inside the server's data directory.
          ENDDESC
        },

        # @!attribute pkg_signing_keychain_pw
        #   @return [String]
        pkg_signing_keychain_pw: {
          default: nil,
          required: true,
          load_method: :data_from_command_file_or_string,
          desc: <<~ENDDESC
            The password to unlock the keychain used for package signing.

            If you start this value with a vertical bar '|', everything after the bar
            is a command to be executed by the server at start-time. The command must
            return the password to standard output.
            This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used

            Otherwise the value is used as the password.

            Be careful of security concerns when passwords are stored in files.
          ENDDESC
        },

        # @!attribute pkg_signing_identity
        #   @return [String]
        pkg_signing_identity: {
          default: nil,
          required: true,
          desc: <<~ENDDESC
            The 'identity' (name) of the package-signing certificate inside the keychain.
            It usually looks something like:

            Developer ID Installer: My Company (XYZXYZYXZXYZ)
          ENDDESC
        },

        # Jamf Pro Connection
        ####################

        # @!attribute jamf_hostname
        #   @return [String]
        jamf_hostname: {
          default: nil,
          required: true,
          desc: <<~ENDDESC
            The hostname of the Jamf Pro server used by xolo.
          ENDDESC
        },

        # @!attribute jamf_port
        #   @return [Integer]
        jamf_port: {
          default: Jamf::Connection::HTTPS_SSL_PORT,
          desc: <<~ENDDESC
            The port number of the Jamf Pro server used by xolo.
            The default is #{Jamf::Connection::HTTPS_SSL_PORT} if the Jamf Pro hostname ends with #{Jamf::Connection::JAMFCLOUD_DOMAIN}
            and #{Jamf::Connection::ON_PREM_SSL_PORT} otherwise.
          ENDDESC
        },

        # @!attribute jamf_ssl_version
        #   @return [Integer]
        jamf_ssl_version: {
          default: Jamf::Connection::DFT_SSL_VERSION,
          desc: <<~ENDDESC
            The SSL version to use for the connection to the Jamf server.
            The default is #{Jamf::Connection::DFT_SSL_VERSION}.
          ENDDESC
        },

        # @!attribute jamf_verify_cert
        #   @return [Boolean]
        jamf_verify_cert: {
          default: true,
          desc: <<~ENDDESC
            Should we verify the SSL certificate used by the Jamf Pro server?
            The default is true.
          ENDDESC
        },

        # @!attribute jamf_open_timeout
        #   @return [Integer]
        jamf_open_timeout: {
          default: Jamf::Connection::DFT_OPEN_TIMEOUT,
          desc: <<~ENDDESC
            The timeout, in seconds, for establishing a connection to the Jamf Pro server.
            The default is #{Jamf::Connection::DFT_OPEN_TIMEOUT}.
          ENDDESC
        },

        # @!attribute jamf_timeout
        #   @return [Integer]
        jamf_timeout: {
          default: Jamf::Connection::DFT_TIMEOUT,
          desc: <<~ENDDESC
            The timeout, in seconds, for getting a response to a request made to the Jamf Pro server.
            The default is #{Jamf::Connection::DFT_TIMEOUT}.
          ENDDESC
        },

        # @!attribute jamf_api_user
        #   @return [Integer]
        jamf_api_user: {
          default: nil,
          required: true,
          desc: <<~ENDDESC
            The username of the Jamf account for connecting to the Jamf Pro APIs.
            TODO: Document the permissions needed by this account.
          ENDDESC
        },

        # @!attribute jamf_api_pw
        #   @return [Integer]
        jamf_api_pw: {
          default: nil,
          required: true,
          load_method: :data_from_command_file_or_string,
          desc: <<~ENDDESC
            The password for the username that connects to the Jamf Pro APIs.

            If you start this value with a vertical bar '|', everything after the bar
            is a command to be executed by the server at start-time. The command must
            return the password to standard output.
            This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used

            Otherwise the value is used as the password.

            Be careful of security concerns when passwords are stored in files.
          ENDDESC
        },

        # @!attribute admin_jamf_group
        #   @return [String]
        admin_jamf_group: {
          default: nil,
          required: true,
          desc: <<~ENDDESC
            The name of a Jamf account-group that allows the use of 'xadm' to create
            and maintain titles and versions.
            Users of xadm must be in this group, and provide their valid Jamf credentials.
          ENDDESC
        },

        # @!attribute upload_tool
        #   @return [String]
        upload_tool: {
          default: nil,
          required: true,
          desc: <<~ENDDESC
            Upload tool - the path to an executable that will upload
            a pkg as needed to make it available to Jamf Pro.

            The only parameter passed to it is the local path to the .pkg
            to be uploaded.

            So if the executable is /usr/local/bin/jamf-pkg-uploader
            then when xolo recieves a pkg to be uploaded to Jamf, it will run
              /usr/local/bin/jamf-pkg-uploader '/Library/Application Support/xolo/uploads/my-new.pkg'

            The upload tool can itself run other tools as needed, e.g. one to upload
            to all fileshare distribution points, and another to upload to a Cloud dist. point.
            or it can do all the things itself.

            An external tool is used here because every Jamf Pro customer has different needs for this,
            e.g. various cloud and file-server distribution points, and Jamf has not provided a
            supported way to upload packages via the APIs. There are some unsupported methods, and
            you are welcome to use them in the external tool you provide here.
          ENDDESC
        },

        # Title Editor Connection
        ####################

        # @!attribute title_editor_hostname
        #   @return [String]
        title_editor_hostname: {
          default: nil,
          required: true,
          desc: <<~ENDDESC
            The hostname of the Title Editor server used by xolo.
          ENDDESC
        },

        # @!attribute title_editor_open_timeout
        #   @return [Integer]
        title_editor_open_timeout: {
          default: Windoo::Connection::DFT_OPEN_TIMEOUT,
          desc: <<~ENDDESC
            The timeout, in seconds, for establishing a connection to the Title Editor server.
            The default is #{Windoo::Connection::DFT_OPEN_TIMEOUT}.
          ENDDESC
        },

        # @!attribute title_editor_timeout
        #   @return [Integer]
        title_editor_timeout: {
          default: Windoo::Connection::DFT_TIMEOUT,
          desc: <<~ENDDESC
            The timeout, in seconds, for getting a response to a request made to the Title Editor server.
            The default is #{Windoo::Connection::DFT_TIMEOUT}.
          ENDDESC
        },

        # @!attribute title_editor_api_user
        #   @return [String]
        title_editor_api_user: {
          default: nil,
          required: true,
          desc: <<~ENDDESC
            The username of the Title Editor account for connecting to the Title Editor API.
            TODO: Document the permissions needed by this account.
          ENDDESC
        },

        # @!attribute title_editor_api_pw
        #   @return [String]
        title_editor_api_pw: {
          default: nil,
          required: true,
          load_method: :data_from_command_file_or_string,
          desc: <<~ENDDESC
            The password for the username that connects to the Title Editor API.

            If you start this value with a vertical bar '|', everything after the bar
            is a command to be executed by the server at start-time. The command must
            return the password to standard output.
            This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used

            Otherwise the value is used as the password.

            Be careful of security concerns when passwords are stored in files.
          ENDDESC
        }

      }.freeze

      # Attributes
      #####################################

      # automatically create accessors for all the CONF_KEYS
      ATTRIBUTES.keys.each { |attr| attr_accessor attr }

      # Constructor
      #####################################

      # Initialize!
      #
      def initialize
        load_from_file
      end

      # Public Instance Methods
      #####################################

      ##################
      def data_dir
        Xolo::Server::DATA_DIR
      end

      ##################
      def log_file
        Xolo::Server::Log::LOG_FILE
      end

      ##################
      def ssl_cert_file
        return @ssl_cert_file if @ssl_cert_file
        raise 'ssl_cert must be set as a string in the config file' unless ssl_cert.is_a? String

        SSL_CERT_FILE.pix_save data_from_command_or_file(ssl_cert)
        @ssl_cert_file = SSL_CERT_FILE
      end

      ##################
      def ssl_key_file
        return @ssl_key_file if @ssl_key_file
        raise 'ssl_key must be set as a string in the config file' unless ssl_key.is_a? String

        SSL_CERT_FILE.pix_save data_from_command_or_file(ssl_key)
        @ssl_key_file = SSL_CERT_FILE
      end

      ###############
      def to_h
        data = {}
        ATTRIBUTES.keys.each { |k| data[k] = send(k) }
        data
      end

      # Private Instance Methods
      #####################################
      private

      # Load in the values from the config file
      # @return [void]
      def load_from_file
        CONF_FILE.parent.mkpath unless CONF_FILE.parent.directory?

        data = YAML.load_file CONF_FILE
        data.each do |k, v|
          v = send ATTRIBUTES[k][:load_method], v if ATTRIBUTES[k][:load_method]
          send "#{k}=", v
        end
      end

      # Save the current config values out to the config file
      # @return [void]
      def save_to_file
        @config_file.pix_save to_h.to_yaml
      end

      # If the given string starts with a pipe (|) then
      # remove the pipe and execute the remainder, returning
      # its stdout.
      #
      # If the given string is a readble file path, return
      # its contents.
      #
      # Otherwise, the string is the desired data, so just return it.
      #
      # @param str [String] a command, file path, or string
      # @return [String] The file contents or output of the command.
      #
      def data_from_command_file_or_string(str)
        return `#{str.delete_prefix(PIPE)}`.chomp if str.start_with? PIPE

        path = Pathname.new(str)
        return path.read.chomp

        str
      end

    end # class Configuration

  end # Server

end # module
