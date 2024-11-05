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
          data = parse_json(request.body.read)
          log_debug "Incoming new title data: #{data}"

          title = instantiate_title data
          halt_on_existing_title title.title

          log_info "Admin #{session[:admin]} is creating title '#{title.title}'"
          with_streaming do
            title.create
            update_client_data
          end
        end

        # get a list of title names
        # @return [Array<Hash>] the data for existing titles
        #################################
        get '/titles' do
          log_debug "Admin #{session[:admin]} is fetching all titles"
          body all_title_objects.map(&:to_h)
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

        # Update a title by
        # replacing the data for an existing title with the content of the request
        # @return [Hash] A response hash
        #################################
        put '/titles/:title' do
          halt_on_missing_title params[:title]
          halt_on_locked_title params[:title]

          title = instantiate_title params[:title]

          request.body.rewind
          new_data = parse_json(request.body.read)
          log_debug "Incoming update title data: #{new_data}"

          log_info "Admin #{session[:admin]} is updating title '#{params[:title]}'"
          with_streaming do
            title.update new_data
            update_client_data
          end
        end

        # Release a version of this title
        #
        # @return [Hash] A response hash
        #################################
        patch '/titles/:title/release/:version' do
          log_info "Admin #{session[:admin]} is releasing version #{params[:version]} of title '#{params[:title]}' via PATCH"

          halt_on_missing_title params[:title]
          halt_on_missing_version params[:title], params[:version]
          halt_on_locked_title params[:title]
          halt_on_locked_version params[:title], params[:version]

          title = instantiate_title params[:title]

          if title.released_version == params[:version]
            msg = "Version '#{params[:version]}' of title '#{params[:title]}' is already released"
            log_debug "ERROR: #{msg}"
            halt 409, { error: msg }
          end

          vers_to_release = params[:version]

          with_streaming do
            title.release vers_to_release
            update_client_data
          end
        end

        # Delete an existing title
        # @return [Hash] A response hash
        #################################
        delete '/titles/:title' do
          halt_on_missing_title params[:title]

          title = instantiate_title params[:title]

          with_streaming do
            title.delete
            update_client_data
          end
        end

        # Handle upload for self-service icon for a title
        #
        # @return [Hash] A response hash
        #################################
        post '/titles/:title/ssvc-icon' do
          process_incoming_ssvc_icon
          body({ result: :uploaded })
        end

        # Return the members of the 'frozen' static group for a title
        #
        # @return [Hash{String => String}] computer name => user name
        #################################
        get '/titles/:title/frozen' do
          log_debug "Admin #{session[:admin]} is fetching frozen computers for title '#{params[:title]}'"
          halt_on_missing_title params[:title]
          title = instantiate_title params[:title]
          body title.frozen_computers
        end

        # add one or more computers to the 'frozen' static group for a title
        # Body should be an array of computer names
        #
        # @return [Hash] A response hash
        #################################
        put '/titles/:title/freeze' do
          request.body.rewind
          log_debug "Incoming request body: #{request.body.read}"
          request.body.rewind

          comps_to_freeze = parse_json(request.body.read)
          log_debug "Incoming computers to freeze for title #{params[:title]}: #{comps_to_freeze}"

          halt_on_missing_title params[:title]
          title = instantiate_title params[:title]

          result = title.freeze_or_thaw_computers(action: :freeze, computers: comps_to_freeze)

          body result
        end

        # remove one or more computers from the 'frozen' static group for a title
        # Body should be an array of computer names
        #
        # If any computer name is 'clear_all' then all frozen computers will be thawed
        #
        # @return [Hash] A response hash
        #################################
        put '/titles/:title/thaw' do
          request.body.rewind
          comps_to_thaw = parse_json(request.body.read)
          log_debug "Incoming computers to thaw for title #{params[:title]}: #{comps_to_thaw}"

          halt_on_missing_title params[:title]
          title = instantiate_title params[:title]

          result = title.freeze_or_thaw_computers(action: :thaw, computers: comps_to_thaw)
          body result
        end

        # Return info about all the computers with a given title installed
        #
        # @return [Array<Hash>] The data for all computers with the given title
        #################################
        get '/titles/:title/patch_report' do
          log_debug "Admin #{session[:admin]} is fetching patch report for title '#{params[:title]}'"
          halt_on_missing_title params[:title]
          title = instantiate_title params[:title]

          body title.patch_report
        end

        # Return URLs for all the UI pages for a title
        #
        # @return [Hash] The URLs for all the UI pages for a title
        #################################
        get '/titles/:title/urls' do
          log_debug "Admin #{session[:admin]} is fetching GUI URLS for title '#{params[:title]}'"
          halt_on_missing_title params[:title]
          title = instantiate_title params[:title]
          data = {
            ted_title_url: title.ted_title_url,
            jamf_patch_title_url: title.jamf_patch_title_url,
            jamf_installed_group_url: title.jamf_installed_group_url,
            jamf_frozen_group_url: title.jamf_frozen_group_url
          }

          if title.version_script
            data[:jamf_patch_ea_url] = title.jamf_patch_ea_url
            data[:jamf_normal_ea_url] = title.jamf_normal_ea_url
          end

          body data
        end

      end # Titles

    end #  Routes

  end #  Server

end # module Xolo
