module Xolo

  # the server app
  module Server

    # tools for working with the server configuration
    # The single instance of this class is stored in
    # Xolo::Server.config
    #
    class Config

      include Singleton

      # The filename for storing the server settings
      CONF_FILE = Pathname.new '/etc/d3server.conf'
      SKIP_LINE_RE = /^\s*(#|$)/
      VALID_LINE_RE = /^(\w+?):\s*(\S.*)$/

      DFT_DATA_DIR = '/Library/Server/d3'.freeze
      DFT_PORT = 443
      DFT_SSL_VERIFY = true
      DFT_SESSION_EXPIRTION = 3600 # 1 hr

      DFT_VERIFY_PKG_SIGNING = false

      DFT_LOG_FILE = Pathname.new '/var/log/d3server.log'
      DFT_LOG_LEVEL = :info
      DFT_LOG_MAX_MEGS = 10
      DFT_LOGS_TO_KEEP = 10

      # keyname: [conversion, default]
      CONF_KEYS = {

        # where the d3 server data is stored
        # mostly in YAML files
        data_dir: [:to_s, DFT_DATA_DIR],

        # path of the ssl key & sert files. If starts with a /, path is
        # absolute path, otherwise, it's relative to the data_dir
        ssl_key: [:to_s],
        ssl_cert: [:to_s],
        ssl_verify: [:jss_to_bool, DFT_SSL_VERIFY],

        # the port on which the d3 server runs
        port: [:to_i, DFT_PORT],

        # Seconds until a session expires
        # TODO: make this static/unsettable? longer?
        session_expiration: [:to_i, DFT_SESSION_EXPIRTION],

        # logging
        log_file: [:to_s, DFT_LOG_FILE],
        log_level: [:to_sym, DFT_LOG_LEVEL],
        log_max_megs:  [:to_i, DFT_LOG_MAX_MEGS],
        logs_to_keep: [:to_i, DFT_LOGS_TO_KEEP],

        # packages

        # only used if server is on macOS, and pkgutil is available
        validate_pkg_signatures: [:jss_to_bool, DFT_VERIFY_PKG_SIGNING],

        # service acct for d3 clients to connect to d3 server
        client_acct: [:to_s],
        client_pw: [:to_s],

        # service acct d3 server to connect to JSS API (readwrite)
        jamf_acct: [:to_s],
        jamf_pw: [:to_s],

        # The name of a JSS acct group.
        # Admins authenticating for d3admin must
        # provide their own valid JSS creds, and
        # be a member of this JSS acct group
        admin_jamf_group: [:to_s],

        # the readwrite password for the master dist point
        # for uploading and deleting pkgs
        master_dist_point_rw_pw: [:to_s],

        # The patch source id for this server
        jss_patch_source_id: [:to_i, 0]

      }.freeze

      # automatically create accessors for all the CONF_KEYS
      CONF_KEYS.keys.each { |k| attr_reader k }

      def initialize
        reload
      end # init

      def reload
        CONF_FILE.read.each_line do |line|
          # skip blank lines and those starting with #
          next if line =~ SKIP_LINE_RE

          # skip those without key: value
          line.strip =~ VALID_LINE_RE
          next unless Regexp.last_match(1)

          key = Regexp.last_match(1).to_sym
          next unless CONF_KEYS.key? key

          value = Regexp.last_match(2).strip
          value = value.send CONF_KEYS[key][0] if value
          instance_variable_set "@#{key}", value
        end # do line
        apply_defaults
      end # reload

      private

      def apply_defaults
        @data_dir ||= DFT_DATA_DIR
        @port ||= DFT_PORT
        @ssl_verify ||= DFT_SSL_VERIFY
        @session_expiration ||= DFT_SESSION_EXPIRTION
        @log_file ||= DFT_LOG_FILE
        @log_level ||= DFT_LOG_LEVEL
        @log_max_megs ||= DFT_LOG_MAX_MEGS
        @log_to_keep ||= DFT_LOGS_TO_KEEP
      end


    end # class Config

    def self.config
      Config.instance
    end

  end # module Server

end # module Xolo
