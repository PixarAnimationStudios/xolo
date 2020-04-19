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

module Xolo

  module Server

    # These routes are only for working with
    # the server data for each title (formerly 'basenames')
    #
    class App < Sinatra::Base

      TITLES_ROUTE_BASE = '/titles'.freeze

      namespace API_V1_ROUTE_BASE do
        namespace TITLES_ROUTE_BASE do
          # titles routes

          # A JSON Array of Hashes, each with summary data about a title
          # A default set of fields are returned, but others can be
          # requested using /?fields=field1,field_4,field3
          #
          get '/?' do
            if params[:fields]
              Xolo::Server::Title.custom_summary_list params[:fields]
            else
              Xolo::Server::Title.json_summary_list
            end
          end

          # create a new title
          post '/:title', api_admin_only: true do
            halt_if_title_already_exists! params[:title]
            request.body.rewind
            title = Xolo::Server::Title.new_from_client_json request.body.read
            title.create session[:user]
            Xolo.logger.info "Created new title '#{params[:title]}' by #{whodat}"
            json_response(
              Xolo::API_OK_STATUS,
              Xolo::API_CREATED_MSG,
              name: title.name,
              added_date: title.added_date.iso8601
            )
          end

          # retrieve a title
          get '/:title' do
            halt_if_title_not_found! params[:title]
            Xolo::Server::Title.fetch(params[:title]).to_json
          end

          # update a title
          put '/:title', api_admin_only: true do
            halt_if_title_not_found! params[:title]
            request.body.rewind
            title = Xolo::Server::Title.new_from_client_json request.body.read
            title.update session[:user]
            Xolo.logger.info "Updated title '#{params[:title]}' by #{whodat}"
            json_response(
              Xolo::API_OK_STATUS,
              Xolo::API_UPDATED_MSG,
              name: title.name,
              last_modified: title.last_modified.iso8601
            )
          end

          # delete a title
          delete '/:title', api_admin_only: true do
            halt_if_title_not_found! params[:title]
            title = Xolo::Server::Title.fetch(params[:title])
            title.delete
            Xolo.logger.info "Deleted title '#{params[:title]}' by #{whodat}"
            json_response(
              Xolo::API_OK_STATUS,
              Xolo::API_DELETED_MSG
            )
          end

          # retrieve a title's change log
          get '/:title/changelog' do
            halt_if_title_not_found! params[:title]
            Xolo::Server::Title.fetch(params[:title]).changelog_json
          end

          # titles nameapace
        end

        # api namespace
      end

    end # class App

  end # module Server

end # module Xolo
