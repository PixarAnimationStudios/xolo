# Copyright 2018 Pixar
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

module D3

  # The sinatra server
  module Server
 class App < Sinatra::Base

    # Server-wide constants
    #####################################

    SESSION_ROUTE_BASE = '/session'.freeze

    SESSION_ROUTE = "#{API_V1_ROUTE_BASE}#{SESSION_ROUTE_BASE}".freeze

    namespace API_V1_ROUTE_BASE do

      # This namespace contains all d3 API session-handling routes
      #########################################
      namespace SESSION_ROUTE_BASE do

        # Create a new d3 API session by POSTing to api/v1/session
        # with HTTP Basic Auth containing the username & pw
        #
        # If the username matches D3::Server.config.client_acct then it's a
        # client session, otherwise, its an admin session.
        #
        #
        post '/?' do
          user, pw = creds_from_basic_auth
          session[:logged_in] = true
          session[:user] = user
          session[:role] = login user, pw
          session[:expires] = Time.now + D3::Server.config.session_expiration
          json_response(
            D3::API_OK_STATUS,
            D3::API_LOGGED_IN_MSG,
            role: session[:role],
            user: session[:user]
          )
        end # post

        # Invalidate the current session
        #
        delete '/?' do
          case session[:role]
          when D3::Server::Helpers::Auth::ADMIN_ROLE
            D3.logger.info "Admin API logout for #{whodat}"
          when D3::Server::Helpers::Auth::CLIENT_ROLE
            D3.logger.debug "Client API logout from #{request.ip}"
          end
          session[:logged_in] = false
          session[:user] = nil
          session[:role] = nil
          session.destroy
          json_response(
            D3::API_OK_STATUS,
            D3::API_LOGGED_OUT_MSG
          )
        end # delete

        get '/valid' do
          if logged_in?
            json_response D3::API_OK_STATUS, D3::API_LOGGED_IN_MSG
          else
            json_response D3::API_ERROR_STATUS, D3::API_NOT_LOGGED_IN_MSG
          end
        end # get valid

      end # namespace session
    end # namespace api

  end # class App
 end # module Server

end # module D3
