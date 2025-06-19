# Copyright 2025 Pixar
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
        post '/titles/:title/versions' do
          request.body.rewind
          data = parse_json request.body.read

          unless data[:title] == params[:title]
            halt 400,
                 "Path/Data Mismatch! params[:title] => '#{params[:title]}' / data[:title] => '#{data[:title]}'"
          end

          log_debug "Incoming new version data: #{data}"
          log_debug "Incoming new version data: #{data.class}"

          vers = instantiate_version(data)
          halt_on_existing_version vers.title, vers.version

          if vers.title_object.jamf_patch_ea_awaiting_acceptance? && !Xolo::Server.config.jamf_auto_accept_xolo_eas

            log_info "Jamf: Patch Title '#{params[:title]}' version_script must be manually accepted as a Patch EA before version can be activated. Admin has been notified."

            raise Xolo::ActionRequiredError,
                  "This title has a version-script, which must be accepted manually in Jamf Pro at #{vers.title_object.jamf_patch_ea_url} under the 'Extension Attribute' tab (click 'Edit'). Please do that and try again"
          end

          log_info "Admin #{session[:admin]} is creating version #{data[:version]} of title '#{params[:title]}'"

          Xolo::Server.rw_lock(data[:title], data[:version]).with_write_lock do
            with_streaming do
              vers.create
              update_client_data
            end
          end
        end

        # get a list of versions for a title
        # @return [Array<Hash>] the names of existing versions for the title
        #################################
        get '/titles/:title/versions' do
          halt_on_missing_title params[:title]

          log_debug "Admin #{session[:admin]} is listing all versions for title '#{params[:title]}'"
          # body all_versions(params[:title])
          vers_ins = all_version_instances(params[:title])
          # log_debug "vers_ins: #{vers_ins}"
          body vers_ins.map(&:to_h)
        end

        # get all the data for a single version
        # @return [Hash] The data for this version
        #################################
        get '/titles/:title/versions/:version' do
          Xolo::Server.rw_lock(params[:title], params[:version]).with_read_lock do
            log_debug "Admin #{session[:admin]} is fetching version '#{params[:version]}' of title '#{params[:title]}'"
            halt_on_missing_version params[:title], params[:version]

            vers = instantiate_version title: params[:title], version: params[:version]
            body vers.to_h
          end
        end

        # Update a version,
        # Replace the data for an existing version with the content of the request
        # @return [Hash] A response hash
        #################################
        put '/titles/:title/versions/:version' do
          request.body.rewind
          new_data = parse_json(request.body.read)
          log_debug "Incoming update version data: #{new_data}"

          halt_on_missing_title params[:title]
          halt_on_missing_version params[:title], params[:version]
          halt_on_locked_version params[:title], params[:version]

          vers = instantiate_version title: params[:title], version: params[:version]

          with_streaming do
            vers.update new_data
            update_client_data
          end
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
          halt_on_locked_version params[:title], params[:version]

          log_info "Admin #{session[:admin]} is deleting version '#{params[:version]}' of title '#{params[:title]}'"

          # for some reason, instantiating in the with_streaming block
          # causes a throw error
          vers = instantiate_version title: params[:title], version: params[:version]

          with_streaming do
            vers.delete
            update_client_data
          end
        end

        # upload a pkg for a version
        # param with the uploaded file must be :file
        ######################
        post '/titles/:title/versions/:version/pkg' do
          process_incoming_pkg
          body({ result: :uploaded })
        end

        # Install a version on computers and/or a group, via
        # the Jamf API's deploy_package endpoint and the
        # InstallEnterpriseApplication MDM command.
        #
        # Request body is a JSON object with the following keys
        #  computers: [Array<String, Integer>] The computer identifiers to install on.
        #     Identifiers are either serial numbers, names, or Jamf IDs.
        #  groups: [Array<String, Integer>] Identifiers of the groups to install on.
        #
        # Response body is a JSON object with the following keys
        #   removals: [Array<Hash>] { device: <Integer>, group: <Integer>, reason: <String> }
        #   queuedCommands: [Array<Hash>] { device: <Integer>, commandUuid: <String> }
        #   errors: [Array<Hash>] { device: <Integer>, group: <Integer>, reason: <String> }
        ######################
        post '/titles/:title/versions/:version/deploy' do
          request.body.rewind
          targets = parse_json(request.body.read)

          log_info "Incoming MDM deployment from admin #{session[:admin]} for title '#{params[:title]}',  version '#{params[:version]}'."
          log_info "MDM deployment targets: #{targets}"

          halt_on_missing_version params[:title], params[:version]

          vers = instantiate_version title: params[:title], version: params[:version]

          result = vers.deploy_via_mdm targets

          body result
        rescue StandardError => e
          msg = "#{e.class}: #{e}"
          log_error msg
          e.backtrace.each { |line| log_error "..#{line}" }
          halt 400, { status: 400, error: msg }
        end

        # Return info about all the computers with a given version of a title installed
        #
        # @return [Array<Hash>] The data for all computers with the given version of the title
        #################################
        get '/titles/:title/versions/:version/patch_report' do
          log_debug "Admin #{session[:admin]} is fetching patch report for version #{params[:version]} title '#{params[:title]}'"

          if params[:version] == Xolo::UNKNOWN
            halt_on_missing_title params[:title]
            title = instantiate_title params[:title]
            data = title.patch_report vers: Xolo::UNKNOWN

          else
            halt_on_missing_version params[:title], params[:version]
            instantiate_version title: params[:title], version: params[:version]

          end

          body data
        end

        # Return URLs for all the UI pages for a version
        #
        # @return [Hash] The URLs for all the UI pages for a version
        #################################
        get '/titles/:title/versions/:version/urls' do
          log_debug "Admin #{session[:admin]} is fetching GUI URLS for version #{params[:version]} of title '#{params[:title]}'"

          halt_on_missing_version params[:title], params[:version]
          vers = instantiate_version title: params[:title], version: params[:version]
          data = {
            ted_patch_url: vers.ted_patch_url,
            jamf_auto_install_policy_url: vers.jamf_auto_install_policy_url,
            jamf_manual_install_policy_url: vers.jamf_manual_install_policy_url,
            jamf_patch_policy_url: vers.jamf_patch_policy_url,
            jamf_package_url: vers.jamf_package_url
          }
          body data
        end

      end # Versions

    end #  Routes

  end #  Server

end # module Xolo
