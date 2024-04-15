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

        # Ping Pong
        ###################
        get '/auth/ping' do
          'auth-pong'
        end

        # Auth a Xolo Admin via Jamf API login
        # Must be a member of the Jamf Admin group
        # named in Xolo::Server.config.admin_jamf_group
        # before
        # TODO: set session cookies etc for multiple interactions
        # for a single xadm process.
        ###################
        post '/auth/login' do
          request.body.rewind
          payload = JSON.parse request.body.read, symbolize_names: true
          user = payload[:username]
          pw = payload[:password]

          err = nil
          err = "User '#{user}' is now allowed to use the Xolo server" unless member_of_admin_jamf_group?(user)
          err = 'Incorrect username or password' unless authenticated_via_jamf?(user, pw)
          halt 401, { error: err }.to_json if err

          { admin: user, authenticated: true }.to_json
        end

      end

    end #  Routes

  end #  Server

end # module Xolo
