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

      module Versions

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

        # Create a new version from the body content of the request
        #
        # @return [Hash] A response hash
        #################################
        post '/titles/:title/versions/:version' do
          halt_on_existing_version params[:title], params[:version]

          request.body.rewind
          data = request.body.read

          log_debug "Incoming new version data: #{data}"
          log_info "Admin #{session[:admin]} is creating version #{params[:version]} of title '#{params[:title]}'"

          vers = instantiate_version parse_json(data)
          with_streaming do
            vers.create
          end
        end

        # get a list of version names for a title
        # @return [Array<String>] the names of existing versions for the title
        #################################
        get '/titles/:title/versions' do
          log_debug "Admin #{session[:admin]} is listing all versions for title '#{params[:title]}'"
          body all_versions(params[:title])
        end

        # get all the data for a single version
        # @return [Hash] The data for this version
        #################################
        get '/titles/:title/versions/:version' do
          log_debug "Admin #{session[:admin]} is fetching version '#{params[:version]}' of title '#{params[:title]}'"
          halt_on_missing_version params[:title], params[:version]

          vers = instantiate_version [params[:title], params[:version]]
          body vers.to_h
        end

        # Replace the data for an existing version with the content of the request
        # @return [Hash] A response hash
        #################################
        put '/titles/:title/versions/:version' do
          log_info "Admin #{session[:admin]} is updating version '#{params[:version]}' of title '#{params[:title]}'"
          halt_on_missing_version params[:title], params[:version]

          vers = instantiate_version [params[:title], params[:version]]

          unless vers.title == params[:title] && vers.version == params[:version]
            msg = "JSON payload title and version '#{vers.title}/#{vers.version}' does not match  URL parameter '#{params[:title]}/#{params[:version]}'"
            log_debug msg
            halt 400, { error: msg }
          end

          request.body.rewind
          new_data = parse_json(request.body.read)
          log_debug "Incoming update version data: #{new_data}"

          vers.update new_data

          resp_content = { title: vers.title, version: vers.version, result: 'updated' }
          body resp_content
        end

        # Delete an existing version
        #
        # This route sends a streamed response indicating progress
        # in realtime, not a JSON object.
        #
        # @return [Hash] A response hash
        #################################
        delete '/titles/:title/versions/:version' do
          halt_on_missing_version params[:title], params[:version]

          log_info "Admin #{session[:admin]} is deleting version '#{params[:version]}' of title '#{params[:title]}'"

          # for some reason, instantiating un the with_streaming block
          # causes a throw error
          data = [params[:title], params[:version]]
          vers = instantiate_version data

          with_streaming do
            vers.delete
          end
        end

      end # Titles

    end #  Routes

  end #  Server

end # module Xolo
