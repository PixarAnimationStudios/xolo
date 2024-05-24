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

    # Some "global" routes are defined here.
    # most are defined in other modules.
    ##################################
    module Routes

      # This is how we extend modules to Sinatra servers:
      # We make them extentions here with
      #    extend Sinatra::Extension (from sinatra-contrib)
      # and then 'register' them in the server with
      #    register Xolo::Server::<Module>
      # Doing it this way allows us to split the code into a logical
      # file structure, without re-opening the Sinatra::Base server app,
      # and let xeitwork do the requiring of those files.
      #
      # To 'include' modules in Sinatra servers, you declare them as helpers.
      #
      extend Sinatra::Extension

      # pre-process
      ##############
      before do
        adm = session[:admin] ? ", admin '#{session[:admin]}'" : Xolo::BLANK
        log_info "Processing #{request.request_method} #{request.path} from #{request.ip}#{adm}"

        # these routes don't need an auth'd session
        break if Xolo::Server::Helpers::Auth::NO_AUTH_ROUTES.include? request.path
        break if Xolo::Server::Helpers::Auth::NO_AUTH_PREFIXES.any? { |pfx| request.path.start_with? pfx }

        # If here, we must have a session cookie marked as 'authenticated'
        # log_debug "Session in before filter: #{session.inspect}"

        halt 401, { error: 'You must log in to the Xolo server' } unless session[:authenticated]
      end

      # error process
      ##############
      error do
        log_debug 'Running error filter'

        resp_body = { status: response.status, error: env['sinatra.error'].message }
        body resp_body
      end

      # post-process
      ##############
      after do
        if @no_json
          log_debug 'NOT converting body to JSON in after filter'
        else
          log_debug 'Converting body to JSON in after filter'
          content_type :json
          # IMPORTANT, this only works if you remember to explicitly use
          # `body body_content` in every route.
          # You can't just define the body
          # by the last evaluated statement of the route.
          #
          response.body = JSON.dump(response.body)
        end

        # TODO: See if there's any appropate place to disconnect
        # from ruby-jss and windoo api connections?
        # perhaps a callback to when a Sinatra server instance
        # 'finishes'?
      end

      # Ping
      ##########
      get '/ping' do
        @no_json = true
        body 'pong'
      end

      # Threads
      ##########
      get '/threads' do
        body Xolo::Server.thread_info
      end

      # State
      ##########
      get '/state' do
        state = {
          executable: Xolo::Server::EXECUTABLE_FILENAME,
          start_time: Xolo::Server.start_time,
          app_env: Xolo::Server.app_env,
          data_dir: Xolo::Server::DATA_DIR,
          log_file: Xolo::Server::Log::LOG_FILE,
          log_level: Xolo::Server::Log::LEVELS[Xolo::Server.logger.level],
          ruby_version: RUBY_VERSION,
          xolo_version: Xolo::VERSION,
          ruby_jss_version: Jamf::VERSION,
          windoo_version: Windoo::VERSION,
          config: Xolo::Server.config.to_h_private,
          threads: Xolo::Server.thread_info
        }

        body state
      end

      # The streamed progress updates
      # The stream_file param should be in the URL query, i.e.
      # "/streamed/progress/?streamed_file=<url-escaped path to file>"
      #
      ################
      get '/streamed_progress/' do
        log_info "Starting progress stream from file: #{params[:stream_file]}"
        @no_json = true
        stream_file = Pathname.new params[:stream_file]

        stream do |stream_out|
          stream_progress(stream_file: stream_file, stream: stream_out)
        rescue StandardError => e
          stream_out << "ERROR DURING PROGRESS STREAM: #{e.class}: #{e}"
        ensure
          stream_out.close
        end
      end

      # test
      ##########
      get '/test' do
        log_error "This isn't really an error, but I'm testing the Xolo Server alert_tool", alert: true
        resp = { status: 'complete' }
        body resp
        # with_streaming do
        #   log_debug "progress_stream_file in thread is: #{progress_stream_file}"
        #   a_long_thing_with_streamed_feedback
        # end
      end

    end #  Routes

  end #  Server

end # module Xolo
