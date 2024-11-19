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

module Xolo

  module Server

    # TODO: Update this text!
    #
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
    # See {KEYS} for the available attributes, and how they are converted to the appropriate
    # Ruby class when loaded.
    #
    # At any point, the attributes can read or ne changed using standard Ruby getter/setter methods
    # matching the name of the attribute,
    # e.g.
    #
    #   # read the current ted_server_name configuration value
    #   Xolo.config.ted_server_name  # => 'foobar.appcatalog.jamfcloud.com'
    #
    #   # sets the ted_server_name to a new value
    #   Xolo.config.ted_server_name = 'baz.appcatalog.jamfcloud.com'
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
    class Configuration < Xolo::Core::BaseClasses::Configuration

      include Singleton

      # Constants
      #####################################
      #####################################

      # Default Values
      ##########

      CONF_FILENAME = 'config.yaml'
      BACKUP_FILE_TIMESTAMP_FORMAT = '%Y%m%d%H%M%S.%N'
      BACKUP_FILE_EXPIRATION_DAYS = 30
      BACKUP_FILE_EXPIRATION_SECS = 120 # BACKUP_FILE_EXPIRATION_DAYS * 24 * 60 * 60

      SSL_DIR = Xolo::Server::DATA_DIR + 'ssl'
      SSL_CERT_FILENAME = 'cert.pem'
      SSL_KEY_FILENAME = 'key.pem'
      SSL_CERT_FILE = SSL_DIR + SSL_CERT_FILENAME
      SSL_KEY_FILE = SSL_DIR + SSL_KEY_FILENAME

      DFT_SSL_VERIFY = true

      PKG_SIGNING_KEYCHAIN_FILENAME = 'xolo-pkg-signing.keychain-db'
      PKG_SIGNING_KEYCHAIN = Xolo::Server::DATA_DIR + PKG_SIGNING_KEYCHAIN_FILENAME

      PIPE = '|'

      PRIVATE = '<private>'

      # if this file exists, the server is in developer mode, and some things do or don't happen
      # see {#developer_mode?}
      DEV_MODE_FILE = Xolo::Server::DATA_DIR + 'dev_mode'

      # Attributes
      #####################################

      # The attribute keys we maintain, and their definitions
      KEYS = {

        # @!attribute ssl_cert
        #   @return [String] A command, path, or value for the SSL Cert.
        ssl_cert: {
          required: true,
          load_method: :data_from_command_file_or_string,
          private: true,
          type: :string,
          desc: <<~ENDDESC
            The SSL Certificate for the https server in .pem format. When the server starts, it will be read from here, and securely stored in #{SSL_CERT_FILE}.

            If you start this value with a vertical bar '|', everything after the bar is a command to be executed by the server at start-time. The command must return the certificate to standard output. This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used.

            Otherwise the value is used as the certificate.

            Be careful of security concerns when certificates are stored in files.
          ENDDESC
        },

        # @!attribute ssl_key
        #   @return [String] A command, path, or value for the SSL Cert private key.
        ssl_key: {
          required: true,
          load_method: :data_from_command_file_or_string,
          private: true,
          type: :string,
          desc: <<~ENDDESC
            The private key for the SSL Certificate in .pem format. When the server starts, it will be read from here, and securely stored in #{SSL_KEY_FILE}/

            If you start this value with a vertical bar '|', everything after the bar is a command to be executed by the server at start-time. The command must return the certificate to standard output. This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used.

            Otherwise the value is used as the certificate.

            Be careful of security concerns when certificates are stored in files.
          ENDDESC
        },

        # @!attribute ssl_verify
        #   @return [Boolean] Should the server verify SSL certs of incoming clients?
        ssl_verify: {
          default: DFT_SSL_VERIFY,
          type: :boolean,
          desc: <<~ENDDESC
            Should the server verify the SSL certificates of machines it communicates with?
          ENDDESC
        },

        # @!attribute admin_jamf_group
        #   @return [String] The name of a Jamf account-group containing users of 'xadm'
        admin_jamf_group: {
          required: true,
          type: :string,
          desc: <<~ENDDESC
            The name of a Jamf account-group (not a User group) that allows the use of 'xadm' to create and maintain titles and versions. Users of xadm must be in this group, and provide their valid Jamf credentials.
          ENDDESC
        },

        # @!attribute log_days_to_keep
        #   @return [Integer] How many days worth of logs to keep
        log_days_to_keep: {
          default: Xolo::Server::Log::DFT_LOG_DAYS_TO_KEEP,
          type: :integer,
          desc: <<~ENDDESC
            The server log is rotated daily. How many days of log files should be kept? All logs are kept in #{Xolo::Server::LOG_DIR}. The current file is named '#{Xolo::Server::LOG_FILE_NAME}', older files are appended with '.YYYYMMDD'.
          ENDDESC
        },

        # @!attribute log_compress_after_days
        #   @return [Integer] How many days worth of logs to keep
        log_compress_after_days: {
          default: Xolo::Server::Log::DFT_LOG_COMPRESS_AFTER_DAYS,
          type: :integer,
          desc: <<~ENDDESC
            Once a log file is rotated, how many days before it is compressed? Compressed logs are named '#{Xolo::Server::LOG_FILE_NAME}.YYYYMMDD.bz2'. It can be accessed using the various bzip2 tools (bzip2, bunzip2, bzcat, bzgrep, etc). If this number is negative, or larger than log_days_to_keep, no logs will be compressed, if it is zero, all older logs will be compressed.
          ENDDESC
        },

        # @!attribute pkg_signing_identity
        #   @return [String] The name of the package signing identity to use
        pkg_signing_identity: {
          required: true,
          type: :string,
          desc: <<~ENDDESC
            Xolo needs to be able to sign at least one of the packages it maintains: the client-data pkg which installs a JSON file of title and version data on the client machines.

            To sign that, or oher packages, you must install a keychain containing a valid package-signing identity on the xolo server at:
              #{PKG_SIGNING_KEYCHAIN}

            The 'identity' (name) of the package-signing certificate inside the keychain must be set here. It usually looks something like:
               Developer ID Installer: My Company (XYZXYZYXZXYZ)

            If desired, you can use this identity to sign other packages as well, see the 'sign_pkgs' config value.
          ENDDESC
        },

        # @!attribute pkg_signing_keychain_pw
        #   @return [String]  A command, path, or value for the password to unlock the pkg_signing_keychain
        pkg_signing_keychain_pw: {
          required: true,
          load_method: :data_from_command_file_or_string,
          private: true,
          type: :string,
          desc: <<~ENDDESC
            The password to unlock the keychain used for package signing.

            If you start this value with a vertical bar '|', everything after the bar is a command to be executed by the server at start-time. The command must return the certificate to standard output. This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used.

            Otherwise the value is used as the password.

            Be careful of security concerns when passwords are stored in files.
          ENDDESC
        },

        # @!attribute sign_pkgs
        #   @return [Boolean] Should the server sign any unsigned uploaded pkgs?
        sign_pkgs: {
          type: :boolean,
          desc: <<~ENDDESC
            When someone uses xadm to upload a .pkg, and it isn't signed, should the server sign it before uploading to Jamf's Distribution Point(s)?

            If you set this to true, it will use the same keychain and identity as the 'pkg_signing_identity' config value to sign the pkg, using the keychain you installed at:
              /Library/Application Support/xoloserver/xolo-pkg-signing.keychain-db

            NOTE: While it may seem insecure to allow the server to sign pkgs, consider:
            - Users of xadm are authenticated and authorized to use the server (see 'admin_jamf_group')
            - You don't need to distribute your signing certificates to a wide group of individual developers.
            - While you need to trust your xadm users not to upload a malicious pkg, this would be true
              even if you deployed the certs to them, so keeping the certs on the server is more secure.
          ENDDESC
        },

        # @!attribute release_to_all_jamf_group
        #   @return [String] The name of a Jamf Pro account-group that is allowed to set release_groups to 'all'
        release_to_all_jamf_group: {
          required: false,
          type: :string,
          desc: <<~ENDDESC
            The name of a Jamf account-group (not a User group) whose members may set a title's release_groups to 'all'.

            When this is set, and someone not in this group tries to set a title's release_groups to 'all', they will get a message telling them to contact the person or group named in 'release_to_all_contact' to get approval.

            To approve the request, one of the members of this group must run 'xadm edit-title <title> --release-groups all'.

            Leave this unset to allow anyone using xadm to set release_groups to 'all' without approval.
          ENDDESC
        },

        # @!attribute release_to_all_contact
        #   @return [String] A string containing contact info for the release_to_all_jamf_group
        release_to_all_contact: {
          required: false,
          type: :string,
          desc: <<~ENDDESC
            When release_to_all_jamf_group is set, and someone not in that group tries to set a title's release_groups to 'all', they are told to use this contact info to get approval.

            This string could be an email address, a chat channel, a phone number, etc.

            Examples:
              - 'jamf-admins@myschool.edu'
              - 'the IT deployment team in the #deployment channel on Slack'
              - 'Bob Parr at 555-555-5555'

            It is presented in text along the lines of:

               Please contact <value> to set release_groups to 'all', letting us know why you think the title should be automatically deployed to all computers.

            This value is required if release_to_all_jamf_group is set.
          ENDDESC
        },

        # @!attribute deprecated_lifetime_days
        #   @return [Integer] How many days after a version is deprecated to keep it
        deprecated_lifetime_days: {
          default: Xolo::Server::Helpers::Maintenance::DFT_DEPRECATED_LIFETIME_DAYS,
          type: :integer,
          desc: <<~ENDDESC
            Once a version is deprecated, it will be automatically deleted by the nightly cleanup this many days later. If set to 0 or less, deprecated versions will never be deleted.

            Deprecated versions are those that have been released, but a newer version has been released since then.

            WARNING: If you set this to 0 or less, you will need to manually delete deprecated versions. Keeping them around can cause confusion and clutter in the GUI, and use up disk space.
          ENDDESC
        },

        # @!attribute keep_skipped_versions
        #   @return [Boolean] Should we keep versions that are skipped?
        keep_skipped_versions: {
          default: false,
          type: :boolean,
          desc: <<~ENDDESC
            Normally, skipped versions are deleted during nightly cleanup. If you set this to true, skipped versions will be kept.

            Skipped versions are those that were never released, but a newer version has been released.

            WARNING: If you set this to true, you will need to manually delete skipped versions. Keeping them around can cause confusion and clutter in the GUI, and use up disk space.
          ENDDESC
        },

        # @!attribute unreleased_pilots_notification_days
        #   @return [Integer] How many days after the newest pilot of a title is created to notify someone
        #      that it hasn't been released yet. Notification is weekly, via the alert_tool
        #      (if defined, see below), and if possible, email to the admin who added the version.
        #      If set to 0 or less, no notifications will be sent.
        unreleased_pilots_notification_days: {
          default: Xolo::Server::Helpers::Maintenance::DFT_UNRELEASED_PILOTS_NOTIFICATION_DAYS,
          type: :integer,
          desc: <<~ENDDESC
            If the newest pilot of a title has not been released in this many days, notify someone about it weekly, asking to release it or delete it. If set to 0 or less, no notifications will be sent. Notifications are sent via the alert_tool (if defined), and if possible, email to the admin who added the version. Default is 180 days (about 6 months).

            Pilot versions are those that have been added for testing, but not yet released.

            This is useful to keep the Xolo clean and up-to-date, and to avoid cluttering with unreleased versions that are no longer relevant.
          ENDDESC
        },

        # Jamf Pro Connection
        ####################

        # @!attribute jamf_hostname
        #   @return [String] The hostname of the Jamf Pro server we are connecting to
        jamf_hostname: {
          required: true,
          type: :string,
          desc: <<~ENDDESC
            The hostname of the Jamf Pro server used by xolo for API access.
          ENDDESC
        },

        # @!attribute jamf_port
        #   @return [Integer] The port number of the Jamf Pro server we are connecting to for API access
        jamf_port: {
          default: Jamf::Connection::HTTPS_SSL_PORT,
          type: :integer,
          desc: <<~ENDDESC
            The port number of the Jamf Pro server used by xolo for API access.
            The default is #{Jamf::Connection::HTTPS_SSL_PORT} if the Jamf Pro hostname ends with #{Jamf::Connection::JAMFCLOUD_DOMAIN} and #{Jamf::Connection::ON_PREM_SSL_PORT} otherwise.
          ENDDESC
        },

        # @!attribute jamf_gui_hostname
        #   @return [String] The hostname of the Jamf Pro server used for links to the GUI webapp
        jamf_gui_hostname: {
          required: true,
          type: :string,
          desc: <<~ENDDESC
            The hostname of the Jamf Pro server used for links to the GUI webapp, if different from the jamf_hostname.
          ENDDESC
        },

        # @!attribute jamf_gui_port
        #   @return [Integer] The port number of the Jamf Pro server used for links to the GUI webapp
        jamf_gui_port: {
          default: Jamf::Connection::HTTPS_SSL_PORT,
          type: :integer,
          desc: <<~ENDDESC
            The port number of the Jamf Pro server used for links to the GUI webapp, if different from the jamf_port.

            The default is #{Jamf::Connection::HTTPS_SSL_PORT} if the Jamf Pro hostname ends with #{Jamf::Connection::JAMFCLOUD_DOMAIN} and #{Jamf::Connection::ON_PREM_SSL_PORT} otherwise.
          ENDDESC
        },

        # @!attribute jamf_ssl_version
        #   @return [String] The SSL version to use when connecting to the Jamd Pro API
        jamf_ssl_version: {
          default: Jamf::Connection::DFT_SSL_VERSION,
          type: :string,
          desc: <<~ENDDESC
            The SSL version to use for the connection to the Jamf API.
          ENDDESC
        },

        # @!attribute jamf_verify_cert
        #   @return [Boolean] Should we verify the SSL certificate of the Jamf Pro API?
        jamf_verify_cert: {
          default: true,
          type: :boolean,
          desc: <<~ENDDESC
            Should we verify the SSL certificate used by the Jamf Pro server?
          ENDDESC
        },

        # @!attribute jamf_open_timeout
        #   @return [Integer] The timeout, in seconds, for establishing http connections to the Jamf Pro API
        jamf_open_timeout: {
          default: Jamf::Connection::DFT_OPEN_TIMEOUT,
          type: :integer,
          desc: <<~ENDDESC
            The timeout, in seconds, for establishing a connection to the Jamf Pro server.
            The default is #{Jamf::Connection::DFT_OPEN_TIMEOUT}.
          ENDDESC
        },

        # @!attribute jamf_timeout
        #   @return [Integer] The timeout, in seconds, for a response from the Jamf Pro API
        jamf_timeout: {
          default: Jamf::Connection::DFT_TIMEOUT,
          type: :integer,
          desc: <<~ENDDESC
            The timeout, in seconds, for getting a response to a request made to the Jamf Pro server.
            The default is #{Jamf::Connection::DFT_TIMEOUT}.
          ENDDESC
        },

        # @!attribute jamf_api_user
        #   @return [String] The username to use when connecting to the Jamf Pro API
        jamf_api_user: {
          required: true,
          type: :string,
          desc: <<~ENDDESC
            The username of the Jamf account for connecting to the Jamf Pro APIs.
            TODO: Document the permissions needed by this account.
          ENDDESC
        },

        # @!attribute jamf_api_pw
        #   @return [String]  A command, path, or value for the password for the Jamf Pro API user
        jamf_api_pw: {
          required: true,
          load_method: :data_from_command_file_or_string,
          private: true,
          type: :string,
          desc: <<~ENDDESC
            The password for the username that connects to the Jamf Pro APIs.

            If you start this value with a vertical bar '|', everything after the bar is a command to be executed by the server at start-time. The command must return the certificate to standard output. This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used.

            Otherwise the value is used as the  password.

            Be careful of security concerns when passwords are stored in files.
          ENDDESC
        },

        # @!attribute jamf_auto_accept_xolo_eas
        #   @return [Boolean] should we auto-accept the Jamf patch title eas?
        jamf_auto_accept_xolo_eas: {
          type: :boolean,
          desc: <<~ENDDESC
            For titles fully maintained by Xolo, should we auto-accept the Patch Title Extension Attributes that come from the uploaded version_script from xadm?

            Default is false, meaning all Title EAs must be manually accepted in the Jamf Pro Web UI.
          ENDDESC
        },

        # @!attribute upload_tool
        #   @return [String] The path to an executable that can upload .pkg files for use by
        #      the Jamf Pro server. The API doesn't provide this ability.
        upload_tool: {
          required: true,
          type: :string,
          desc: <<~ENDDESC
            After a .pkg is uploaded to the Xolo server by someone using xadm, it must then be uploaded to the Jamf distribution point(s) to be available for installation.

            This value is the path to an executable on the xolo server that will do that second upload to the distribution point(s).

            It will be run with two arguments:
            - The display name of the Jamf::Package object the .pkg is used with
            - the path to the .pkg file on the Xolo server, which will be uploaded
              to the Jamf distribution point(s).

            So if the executable is '/usr/local/bin/jamf-pkg-uploader' then when Xolo recieves a .pkg to be uploaded to Jamf, it will run something like:

              /usr/local/bin/jamf-pkg-uploader 'CoolApp' '/Library/Application Support/xoloserver/tmpfiles/CoolApp.pkg'

            Where 'CoolApp' is the name of the Jamf Package object that will use this .pkg, and '/Library/Application Support/xoloserver/tmpfiles/CoolApp.pkg' is the location where it was stored on the Xolo server when xadm uploaded it.

            The upload tool can itself run other tools as needed, e.g. one to upload
            to all fileshare distribution points, and another to upload to a Cloud dist. point.
            or it can do all the things itself.

            After that tool runs, the copy of the .pkg on the server ( '/Library/Application Support/xoloserver/tmpfiles/CoolApp.pkg' in the example above) will be deleted.

            An external tool is used here because every Jamf Pro customer has different needs for this, e.g. various cloud and file-server distribution points, and Jamf has not provided asupported way to upload packages to all possible Dist Points via the APIs.

            There are some unsupported methods, and you are welcome to use them in the external tool you provide here.  As Jamf supports API-based package uploads, xolo will be updated to use them.
          ENDDESC
        },

        # @!attribute alert_tool
        #   @return [String] A command and its options/args that relays messages from stdin to some means
        #       of alerting Xolo server admins of a problem or event that would otherwise go unnoticed.
        #
        alert_tool: {
          type: :string,
          desc: <<~ENDDESC
            Server errors or other events that happen as part of xadm actions are reported to the xadm user. But sometimes such events happen outside of the scope of a xadm session. While these events will be logged, you might want them reported to a server administrator in real time.

            This value is a command (path to executable plus CLI args) on the Xolo server which will accept an error or other alert message on standard input and send it somewhere where it'll be seen by an appropriate audiance, be that an email address, a Slack channel - anything you'd like.

            Fictional example: /path/to/slackerator --sender xolo-server --channel xolo-alerts --icon dante
          ENDDESC
        },

        # @!attribute forced_exclusion
        #   @return [String] The name of a single Jamf Pro computer groups that will ALWAYS be excluded
        #      and will never see any titles or versions in Xolo.
        forced_exclusion: {
          type: :string,
          desc: <<~ENDDESC
            If you have any jamf computers who should never even know that xolo exists, and should never have any software installed via xolo, put them into a group and put that group's name here.

            An example would be a group of machines that should have a very minimalist management footprint, only enforcing basic security settings and nothing else.

            This group, if defined, will be in the exclusions of all policies and patch policies maintained by Xolo.

            NOTE: These machines are still managed, and software can still be installed via Jamf if desired, but outside of Xolo.
          ENDDESC
        },

        # Title Editor
        ####################

        # @!attribute ted_patch_source
        #   @return [String] The name of the Patch Source in Jamf Pro that points at the Title Editor.
        ted_patch_source: {
          type: :string,
          required: true,
          desc: <<~ENDDESC
            The name in Jamf Pro of the Title Editor as an External Patch Source.
          ENDDESC
        },

        # @!attribute ted_hostname
        #   @return [String] The hostname of the Jamf Title Editor server we are connecting to
        ted_hostname: {
          type: :string,
          required: true,
          desc: <<~ENDDESC
            The hostname of the Title Editor server used by xolo.
          ENDDESC
        },

        # @!attribute ted_open_timeout
        #   @return [Integer] The timeout, in seconds, for establishing http connections to
        #      the Jamf Title Editor API
        ted_open_timeout: {
          default: Windoo::Connection::DFT_OPEN_TIMEOUT,
          type: :integer,
          desc: <<~ENDDESC
            The timeout, in seconds, for establishing a connection to the Title Editor server.
          ENDDESC
        },

        # @!attribute ted_timeout
        #   @return [Integer] The timeout, in seconds, for a response from the Jamf Title Editor API
        ted_timeout: {
          default: Windoo::Connection::DFT_TIMEOUT,
          type: :integer,
          desc: <<~ENDDESC
            The timeout, in seconds, for getting a response to a request made to the Title Editor server.
          ENDDESC
        },

        # @!attribute ted_api_user
        #   @return [String]  The username to use when connecting to the Jamf Title Editor API
        ted_api_user: {
          required: true,
          type: :string,
          desc: <<~ENDDESC
            The username of the Title Editor account for connecting to the Title Editor API.
            TODO: Document the permissions needed by this account.
          ENDDESC
        },

        # @!attribute ted_api_pw
        #   @return [String] A command, path, or value for the password for the Jamf Title Editor API user
        ted_api_pw: {
          required: true,
          load_method: :data_from_command_file_or_string,
          private: true,
          type: :string,
          desc: <<~ENDDESC
            The password for the username that connects to the Title Editor API.

            If you start this value with a vertical bar '|', everything after the bar is a command to be executed by the server at start-time. The command must return the certificate to standard output. This is useful when using a secret-storage system to manage secrets.

            If the value is a path to a readable file, the file's contents are used.

            Otherwise the value is used as the password.

            Be careful of security concerns when passwords are stored in files.
          ENDDESC
        }

      }.freeze

      # Public Instance Methods
      #####################################
      #####################################

      # @return [Pathname] The file that stores configuration values
      #######################
      def conf_file
        @conf_file ||= Xolo::Server::DATA_DIR + CONF_FILENAME
      end

      ###############
      def save_to_file(data: nil)
        backup_conf_file
        super
        clean_old_backups
      end

      ################
      def backup_conf_file
        return unless conf_file.file?

        backup_file_dir.mkpath unless backup_file_dir.directory?

        backup_file_name = "#{conf_file.basename}.#{Time.now.strftime BACKUP_FILE_TIMESTAMP_FORMAT}"
        backup_file = backup_file_dir + backup_file_name
        conf_file.pix_cp backup_file
      end

      ################
      def backup_file_dir
        @backup_file_dir ||= Xolo::Server::BACKUPS_DIR + 'config'
      end

      # remove all backups older than BACKUP_FILE_EXPIRATION_DAYS, except the most recent
      ################
      def clean_old_backups
        return unless backup_file_dir.directory?

        newest_file = backup_file_dir.children.max_by(&:mtime)
        oldest_ok_time = Time.now - BACKUP_FILE_EXPIRATION_SECS

        backup_file_dir.each_child do |file|
          next unless file.file?
          next if file == newest_file

          file.unlink if file.mtime < oldest_ok_time
        end
      end

      # @return [Pathname] The directory where the Xolo server stores data
      ##################
      def data_dir
        Xolo::Server::DATA_DIR
      end

      # @return [Pathname] The file where Xolo server log entries are written
      ##################
      def log_file
        Xolo::Server::Log::LOG_FILE
      end

      # This file will be created based on the config value the first
      # time this method is called
      #
      # @return [Pathname] The file where the SSL certificate[-chain] is stored
      #   for use by the server.
      ##################
      def ssl_cert_file
        return @ssl_cert_file if @ssl_cert_file
        raise 'ssl_cert must be set as a string in the config file' unless ssl_cert.is_a? String

        SSL_CERT_FILE.pix_save data_from_command_or_file(ssl_cert)
        @ssl_cert_file = SSL_CERT_FILE
      end

      # This file will be created based on the config value the first
      # time this method is called
      #
      # @return [Pathname] The file where the SSL certificate private key is stored
      #   for use by the server.
      ##################
      def ssl_key_file
        return @ssl_key_file if @ssl_key_file
        raise 'ssl_key must be set as a string in the config file' unless ssl_key.is_a? String

        SSL_CERT_FILE.pix_save data_from_command_or_file(ssl_key)
        @ssl_key_file = SSL_CERT_FILE
      end

      # @return [Boolean] are we in developer mode? If so, some actions do or don't happen
      ##################
      def developer_mode?
        DEV_MODE_FILE.file?
      end

      # @return [Hash] a hash of the configuration values, with private values replaced by '<private>'
      # and server specific values added
      #
      def to_h
        hash = super
        hash[:developer_mode] = developer_mode?
        hash
      end

    end # class Configuration

  end # Server

end # module
