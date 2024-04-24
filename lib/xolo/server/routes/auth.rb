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

    module Routes

      module Auth

        # This is how we 'mix in' modules to Sinatra servers:
        # We make them extentions here with
        #    extend Sinatra::Extension (from sinatra-contrib)
        # and then 'register' them in the server with
        #    register Xolo::Server::<Module>
        # Doing it this way allows us to split the code into a logical
        # file structure, without re-opening the Sinatra::Base server app,
        # and let xeitwork do the requiring of those files
        extend Sinatra::Extension

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # Auth a Xolo Admin via Jamf API login
        # Must be a member of the Jamf Admin group
        # named in Xolo::Server.config.admin_jamf_group
        # before
        ###################
        post '/auth/login' do
          request.body.rewind
          payload = parse_json request.body.read
          admin = payload[:admin]
          pw = payload[:password]

          logger.debug "Authenticating admin '#{admin}'"

          err = nil
          err = "'#{admin}' is not allowed to use the Xolo server" unless member_of_admin_jamf_group?(admin)

          err ||= 'Incorrect xolo admin username or password' unless authenticated_via_jamf?(admin, pw)

          if err
            logger.debug "Authentication failed for '#{admin}': #{err}"
            halt 401, { error: err }
          end

          # Set the session values
          session[:admin] = admin
          session[:authenticated] = true

          body({ admin: admin, authenticated: true })
        end

      end

    end #  Routes

  end #  Server

end # module Xolo
