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
        # @return [Hash] A response hash
        #################################
        post '/titles' do
          request.body.rewind
          data = request.body.read
          log_debug "Incoming new title data: #{data}"

          title = Xolo::Server::Title.new parse_json(data)
          title.session = session

          if all_titles.include? title.title
            msg = "Title '#{title.title}' already exists"
            log_debug "ERROR: Admin #{session[:admin]}: #{msg}"
            halt 409, { error: msg }
          end

          log_info "Admin #{session[:admin]} is creating new title '#{title.title}'"
          title.save

          resp_content = { title: title.title, status: 'saved' }
          body resp_content
        end

        # get a list of title names
        # @return [Array<String>] the names of existing titles
        #################################
        get '/titles' do
          log_debug "Admin #{session[:admin]} is listing all titles'"
          body all_titles
        end

        # get all the data for a single title
        # @return [Hash] The data for this title
        #################################
        get '/titles/:title' do
          unless all_titles.include? params[:title]
            msg = "Title '#{params[:title]}' does not exist."
            log_debug "ERROR: Admin #{session[:admin]}: #{msg}"
            halt 404, { error: msg }
          end

          title = Xolo::Server::Title.load params[:title]
          title.session = session
          body title.to_h
        end

        # Replace the data for an existing title with the content of the request
        # @return [Hash] A response hash
        #################################
        put '/titles' do
          request.body.rewind
          data = request.body.read
          log_debug "Incoming update title data: #{data}"

          title = Xolo::Server::Title.new parse_json(data)
          title.session = session

          unless all_titles.include? title.title
            msg = "Title '#{title.title}' does not exist."
            log_debug "ERROR: Admin #{session[:admin]}: #{msg}"
            halt 404, { error: msg }
          end

          log_info "Admin #{session[:admin]} is updating title '#{title.title}'"
          title.modification_date = Time.now
          title.modified_by = session[:admin]
          title.save

          resp_content = { title: title.title, status: 'updated' }
          body resp_content
        end

        # Delete an existing title
        # @return [Hash] A response hash
        #################################
        delete '/titles/:title' do
          unless all_titles.include? params[:title]
            msg = "Title '#{params[:title]}' does not exist."
            log_debug "ERROR: Admin #{session[:admin]}: #{msg}"
            halt 404, { error: msg }
          end

          title = Xolo::Server::Title.load params[:title]
          title.session = session

          log_info "Admin #{session[:admin]} is deleting title '#{title.title}'"
          title.delete

          resp_content = { title: params[:title], status: 'deleted' }
          body resp_content
        end

      end

    end #  Routes

  end #  Server

end # module Xolo
