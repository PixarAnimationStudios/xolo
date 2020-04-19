module Xolo

  module Server

    module Helpers

      # Helper and Module methods dealing with API authenication
      module Auth

        # the two ways we can authenticate
        ADMIN_ROLE = :admin
        CLIENT_ROLE = :client

        AUTH_ROLES = [ADMIN_ROLE, CLIENT_ROLE].freeze

        # Module methods - they don't become helper instance methods
        # in routes & filters, but are available everywhere when
        # fully qualified
        ###################################

        # load in the pw when first used, and access it here
        def self.client_pw
          @client_pw ||= pw_from_conf(Xolo::Server.config.client_pw)
        end

        # load in the pw when first used, and access it here
        def self.jamf_pw
          @jamf_pw ||= pw_from_conf(Xolo::Server.config.jamf_pw)
        end

        # load in the pw when first used, and access it here
        def self.dist_point_pw
          @dist_point_pw ||= pw_from_conf(Xolo::Server.config.master_dist_point_rw_pw)
        end

        # read a password defined in a config setting
        def self.pw_from_conf(config_value)
          return '' unless config_value
          return pw_from_command(config_value) if config_value.end_with? '|'
          pw_from_file config_value
        end

        # if the passwd setting ends with a pipe, its a command
        # that will return the desired password, so remove the
        # pipe, execute it, and return stdout from it.
        def self.pw_from_command(cmd)
          cmd = cmd.chomp '|'
          output = `#{cmd} 2>&1`.chomp
          raise "Can't get password from #{setting}: #{output}" unless $CHILD_STATUS.exitstatus.zero?
          output
        end

        # Passwd setting is a file path, so read the pw
        # from the contents and return it
        def self.pw_from_file(file)
          file = Pathname.new file
          return nil unless file.file?
          stat = file.stat
          mode = format('%o', stat.mode)
          raise "Password file #{setting} has insecure mode, must be 0600." unless mode.end_with?('0600')
          raise "Password file #{setting} has insecure owner, must be owned by UID #{Process.euid}." unless stat.owned?
          # chomping an empty string removes all trailing \n's and \r\n's
          file.read.chomp('')
        end

        # Instance methods - they become helper instance methods
        # in routes & filters
        ###################################

        def logged_in?
          session[:logged_in] && \
            Xolo::Server::Helpers::Auth::AUTH_ROLES.include?(session[:role]) && \
            session[:expires] && Time.now < session[:expires]
        end

        # Extract the basic auth credentials from the HTTP request
        # or halt if not provided
        #
        # @return [Array<String>] username and passwd provided via Basic Auth
        #
        def creds_from_basic_auth
          auth ||= Rack::Auth::Basic::Request.new(request.env)
          halt_login_failed!(:error, 'No authentication credentials provided') unless auth.provided? && auth.basic? && auth.credentials
          auth.credentials
        end

        # log in to the d3 API
        #
        # @param user[String] the username to login
        #
        # @param pw[String] the password for the user
        #
        # @return [Symbol] The role, a member of AUTH_ROLES,
        #   CLIENT_ROLE if user == Xolo::Server.config.client_acct
        #   ADMIN_ROLE if user != Xolo::Server.config.client_acct
        #   Halt with error if authentication fails
        #
        def login(user, pw)
          role, failed_msg =
            if user == Xolo::Server.config.client_acct
              authenticate_client pw
            else
              authenticate_admin user, pw
            end
          return role unless failed_msg
          halt_login_failed! role, failed_msg
        end

        # Validate that a user/pw are valid in the JSS and member of the
        # d3admin group defined in the config.
        #
        # @param creds[Array<String>] username and passwd for the JSS
        #
        # @return [String] username if valid, error message if not
        #
        def authenticate_admin(admin_user, admin_pw)
          failed = false
          failed = "JSS authentication failed for admin: #{admin_user}" unless jss_authed? admin_user, admin_pw
          failed = "JSS user #{admin_user} not in admin group" unless failed || in_admin_group?(admin_user)
          D3.logger.info "Admin API login for #{admin_user}@#{request.ip}" unless failed
          [ADMIN_ROLE, failed]
        end # authenticate_webhooks_user

        # Validate that a user/pw are valid in the JSS and member of the
        # d3admin group defined in the config.
        #
        # @param creds[Array<String>] username and passwd for the JSS
        #
        # @return [Symbol, String] CLIENT_ROLE if valid, error message if not
        #
        def authenticate_client(client_pw)
          client_user = Xolo::Server.config.client_acct
          failed = false
          failed = 'Client authentication failed' unless client_pw == Xolo::Server::Helpers::Auth.client_pw
          D3.logger.debug "Client API login from #{request.ip}" unless failed
          [CLIENT_ROLE, failed]
        end # authenticate_webhooks_user

        # Validate that a user/pw are valid in the JSS
        # Authenticate a JSS name and pw by making a connection
        #
        # @param username[String] the username to authenticate
        #
        # @param pw[String] the pw for the user
        #
        # @return [Boolean] Were the name and passwd accepted by the JSS?
        #
        def jss_authed?(username, pw)
          JSS::APIConnection.new user: username, pw: pw
          true
        rescue JSS::AuthenticationError
          false
        end

        # Verify that a user is in the JSS group defined in
        # Xolo::Server.config.admin_jamf_group
        #
        # @param username[String] the username to verify
        #
        # @return [Boolean] Is the user in the group?
        #
        def in_admin_group?(acct_name)
          groupname = Xolo::Server.config.admin_jamf_group
          grp_raw = JSS.api.get_rsrc("accounts/groupname/#{groupname}")[:group]
          ldap_server = grp_raw[:ldap_server]
          if ldap_server
            member_check = JSS.api.get_rsrc "ldapservers/id/#{ldap_server[:id]}/group/#{CGI.escape groupname}/user/#{acct_name}"
            return false if member_check[:ldap_users].empty?
            true
          else
            grp_raw[:members].each { |m| return true if m[:name] == acct_name }
            false
          end
        end # in admin group?

        def whodat
          "#{session[:user]}@#{request.ip}"
        end

      end # module auth

    end # module api

  end # module server

end # module Xolo
