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

# main module
module Xolo

  # Server Module
  module Server

    module Helpers

      module Auth

        # Constants
        #####################
        #####################

        # these routes don't need an auth'd session
        NO_AUTH_ROUTES = [
          '/ping',
          '/auth/login'
        ].freeze

        # these route prefixes don't need an auth'd session
        NO_AUTH_PREFIXES = [
          '/ping/'
        ].freeze

        # these routes are expected to be called by the xolo server itself
        # and will have the internal_auth_token in the headers
        # and will come from IPV4_LOOPBACK
        INTERNAL_ROUTES = [
          '/cleanup'
        ].freeze

        # these routes must
        SERVER_ADMIN_ROUTES = [
          '/state',
          '/cleanup',
          '/update-client-data',
          '/rotate-logs',
          '/set-log-level'
        ].freeze

        # The loopback address for IPV4
        IPV4_LOOPBACK = '127.0.0.1'

        # Module methods
        #####################
        #####################

        # when this module is included
        #####################
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # If a request comes in from one of our known IP addresses
        # with a valid internal_auth_toke in the headers, then the request is allowed.
        #
        # This allows the xolo server to send requests to itself without needing
        # to authenticate, as is needed for some kinds of maintenance tasks
        # such as cleanup.
        #
        # The token value is generated anew at startup and is a long random string, it
        # is only available to the xolo server itself from its memory, and
        # is never stored.
        #
        # @return [String] The internal_auth_token to be used in the Authorization header of requests
        #####################
        def self.internal_auth_token_header
          @internal_auth_token_header ||= "Bearer #{SecureRandom.hex(64)}"
        end

        # Instance methods
        #####################
        #####################

        # Is the internal_auth_token in the headers of the request?
        # and is the request coming from one of our known IP addresses?
        #
        # @return [Boolean] Is this a valid request from the xolo server itself?
        #####################
        def valid_internal_auth_token?
          log_info "Checking internal auth token from #{request.ip}"

          if !internal_ip_ok?
            warning = "Invalid IP address for internal request: #{request.ip}"
          elsif !internal_token_ok?
            warning = "Invalid internal auth token '#{request.env['HTTP_AUTHORIZATION']}' from #{request.ip}"
          else
            log_info "Internal request for #{request.path} is valid"
            return true
          end

          log_warn "WARNING: #{warning}"
          halt 403, { error: 'You do not have access to this resource' }
        end

        # @return [Boolean] Is the internal_auth_token in the headers of the request?
        #####################
        def internal_token_ok?
          request.env['HTTP_AUTHORIZATION'] == Xolo::Server::Helpers::Auth.internal_auth_token_header
        end

        # @return [Boolean] Is the request coming from one of our known IP addresses?
        #####################
        def internal_ip_ok?
          # server_ip_addresses.include? request.ip
          # always require the request to come from the loopback address
          request.ip == Xolo::Server::Helpers::Auth::IPV4_LOOPBACK
        end

        # @return [Array<String>] The IP addresses of this server
        #####################
        def server_ip_addresses
          Socket.ip_address_list.map(&:ip_address)
        end

        # is the given username a member of the admin_jamf_group?
        # or the server_admin_jamf_group?
        # If not, they are not allowed to talk to the xolo server.
        #
        # @param admin_name [String] The jamf acct name of the person seeking access
        #
        # @return [Boolean] Is the admin a member of the admin_jamf_group?
        #####################
        def member_of_admin_jamf_group?(admin_name)
          log_info "Checking if '#{admin_name}' is allowed to access the Xolo server"

          groupname = Xolo::Server.config.admin_jamf_group
          return true if user_in_jamf_acct_group?(groupname, admin_name)

          # if they're not in the admin group, check the server_admin group
          return true if member_of_server_admin_jamf_group?(admin_name)

          log_info "'#{admin_name}' is not a member of the admin_jamf_group or the server_admin_jamf_group"
          false
        end

        # is the given username a member of the server_admin_jamf_group?
        # they must be in order to access the server admin routes
        #
        # @param admin_name [String] The jamf acct name of the person seeking access
        #
        # @return [Boolean] Is the admin a member of the server_admin_jamf_group?
        #####################
        def member_of_server_admin_jamf_group?(admin_name)
          return false unless Xolo::Server.config.server_admin_jamf_group

          log_info "Checking if '#{admin_name}' is allowed to access server admin routes"

          groupname = Xolo::Server.config.server_admin_jamf_group
          return true if user_in_jamf_acct_group?(groupname, admin_name)

          log_info "'#{admin_name}' is not a member of the server_admin_jamf_group '#{groupname}'"
          false
        end

        # is the session[:admin] a member of the server_admin_jamf_group,
        # and has a valid session?
        #
        # @return [Boolean]
        #####################
        def valid_server_admin?
          return true if session[:authenticated] && member_of_server_admin_jamf_group?(session[:admin])

          halt 403, { error: 'You do not have access to that resource.' }
        end

        # is the given username a member of the release_to_all_approval_group?
        # If not, they are not allowed to set a title's release_groups to 'all'.
        #
        # @param admin_name [String] The jamf acct name of the person
        #
        # @return [Boolean] Is the admin allowed to set release_groups to all?
        #####################
        def allowed_to_release_to_all?(admin_name)
          log_debug "Checking if '#{admin_name}' is allowed to release to all"

          groupname = Xolo::Server.config.release_to_all_jamf_group
          if groupname.pix_empty?
            log_debug 'No release_to_all_jamf_group defined, allowing all admins to release to all'
            return true
          end

          if user_in_jamf_acct_group?(groupname, admin_name)
            log_debug "'#{admin_name}' is allowed to release to all"
            true
          else
            log_debug "'#{admin_name}' is not allowed to release to all"
            false
          end
        ensure
          jamf_cnx&.disconnect
        end

        # check to see if a username is a member of a Jamf AccountGroup either from Jamf or from LDAP
        #
        def user_in_jamf_acct_group?(groupname, username)
          log_debug "Checking if '#{username}' is a member of the Jamf AccountGroup '#{groupname}'"

          # This isn't well implemented in ruby-jss, so use c_get directly
          jgroup = jamf_cnx.c_get("accounts/groupname/#{groupname}")[:group]

          if jgroup[:ldap_server]
            Jamf::LdapServer.check_membership jgroup[:ldap_server][:id], username, groupname, cnx: jamf_cnx
          else
            jgroup[:members].any? { |m| m[:name] == username }
          end
        rescue Jamf::NoSuchItemError
          false
        end

        # Try to authenticate the jamf user trying to log in to xolo
        #
        # @param admin [String] The jamf acct name of the person seeking access
        #
        # @param pw [String] The password for the jamf acct
        #
        # @return [Boolean] Did the password work for the user?
        #####################
        def authenticated_via_jamf?(admin, pw)
          log_debug "Checking Jamf authentication for admin '#{admin}'"
          login_cnx = Jamf::Connection.new(
            host: Xolo::Server.config.jamf_hostname,
            port: Xolo::Server.config.jamf_port,
            verify_cert: Xolo::Server.config.jamf_verify_cert,
            open_timeout: Xolo::Server.config.jamf_open_timeout,
            timeout: Xolo::Server.config.jamf_timeout,
            user: admin,
            pw: pw
          )
          login_cnx.disconnect
          true
        rescue Jamf::AuthenticationError
          false
        end

      end

    end #  Routes

  end #  Server

end # module Xolo
