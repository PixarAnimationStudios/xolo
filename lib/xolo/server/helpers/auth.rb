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

# main module
module Xolo

  # Server Module
  module Server

    module Helpers

      module Auth

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # is the given username a member of the admin_jamf_group?
        # If not, they are not allowed to talk to the xolo server.
        #
        # @param admin_name [String] The jamf acct name of the person seeking access
        #
        # @return [Boolean] Is the admin a member of the admin_jamf_group?
        #
        def member_of_admin_jamf_group?(admin_name)
          groupname = Xolo::Server.config.admin_jamf_group
          jgroup = Jamf.cnx.c_get("accounts/groupname/#{groupname}")[:group]

          if jgroup[:ldap_server]
            Jamf::LdapServer.check_membership jgroup[:ldap_server][:id], admin_name, groupname
          else
            jgroup[:members].any? { |m| m[:name] == admin_name }
          end
        end

        # Try to authenticate the jamf user trying to log in
        #
        # @param admin [String] The jamf acct name of the person seeking access
        #
        # @param pw [String] The password for the jamf acct
        #
        # @return [Boolean] Did the password work for the user?
        #
        def authenticated_via_jamf?(admin, pw)
          Jamf::Connection.new(
            host: Xolo::Server.config.jamf_hostname,
            port: Xolo::Server.config.jamf_port,
            verify_cert: Xolo::Server.config.jamf_verify_cert,
            ssl_version: Xolo::Server.config.jamf_ssl_version,
            open_timeout: Xolo::Server.config.jamf_open_timeout,
            timeout: Xolo::Server.config.jamf_timeout,
            user: admin,
            pw: pw
          )
          true
        rescue Jamf::AuthenticationError
          false
        end

      end

    end #  Routes

  end #  Server

end # module Xolo
