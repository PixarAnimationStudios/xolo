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

    module Routes

      module Titles

        # This is how we 'mix in' modules to Sinatra servers
        # for route definitions and similar things
        #
        # (things to be 'included' for use in route and view processing
        # are mixed in by delcaring them to be helpers)
        #
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

        # Create a new title from the body content of the request
        #
        # @return [Hash] A response hash
        #################################
        post '/titles' do
          request.body.rewind
          data = request.body.read
          log_debug "Incoming new title data: #{data}"
          title = instantiate_title parse_json(data)

          halt_on_existing_title title.title

          title.create

          resp_content = { title: title.title, status: 'saved' }
          body resp_content
        end

        # get a list of title names
        # @return [Array<String>] the names of existing titles
        #################################
        get '/titles' do
          log_debug "Admin #{session[:admin]} is listing all titles"
          body all_titles
        end

        # get all the data for a single title
        # @return [Hash] The data for this title
        #################################
        get '/titles/:title' do
          log_debug "Admin #{session[:admin]} is fetching title '#{params[:title]}'"
          halt_on_missing_title params[:title]

          title = instantiate_title params[:title]
          body title.to_h
        end

        # Replace the data for an existing title with the content of the request
        # @return [Hash] A response hash
        #################################
        put '/titles/:title' do
          log_info "Admin #{session[:admin]} is updating title '#{params[:title]}'"
          halt_on_missing_title params[:title]

          title = instantiate_title params[:title]

          unless title.title == params[:title]
            msg = "Title in JSON payload '#{title.title}' does not match title in URL parameter '#{params[:title]}'"
            log_debug msg
            halt 400, { error: msg }
          end

          request.body.rewind
          new_data = parse_json(request.body.read)
          log_debug "Incoming update title data: #{new_data}"

          title.update new_data

          resp_content = { title: title.title, status: 'updated' }
          body resp_content
        end

        # Delete an existing title
        # @return [Hash] A response hash
        #################################
        delete '/titles/:title' do
          resp_content =
            if all_titles.include? params[:title]
              title = instantiate_title params[:title]
              log_info "Admin #{session[:admin]} is deleting title '#{title.title}'"
              title.delete
              { title: params[:title], status: 'deleted' }
            else
              { title: params[:title], status: "doesn't exist, not deleted" }
            end

          body resp_content
        end

        # Add or update the version-script for a title
        #
        # @return [Hash] A response hash
        #################################
        post '/titles/:title/version_script' do
          log_info "Admin #{session[:admin]} is updating the version script for title '#{params[:title]}'"
          halt_on_missing_title params[:title]

          title = instantiate_title params[:title]
        end

      end # Titles

    end #  Routes

  end #  Server

end # module Xolo
