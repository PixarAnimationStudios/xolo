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

      module Maint

        # This is how we 'mix in' modules to Sinatra servers:
        # We make them extentions here with
        #    extend Sinatra::Extension (from sinatra-contrib)
        # and then 'register' them in the server with
        #    register Xolo::Server::<Module>
        # Doing it this way allows us to split the code into a logical
        # file structure, without re-opening the Sinatra::Base server app,
        # and let zeitwork do the requiring of those files
        extend Sinatra::Extension

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # when this module is extended
        def self.extended(extender)
          Xolo.verbose_extend extender, self
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
            pkg_deletion_pool: Xolo::Server::Version.pkg_deletion_pool_info,
            object_locks: Xolo::Server.object_locks,
            threads: Xolo::Server.thread_info
          }

          body state
        end

        # run the cleanup process from the internal timer task
        # The before filter will ensure the request came from the server itself.
        # with a valid internal auth token.
        ################
        post '/cleanup-internal' do
          log_info 'Starting internal cleanup'

          thr = Thread.new { cleanup_versions }
          thr.name = 'Internal Cleanup Thread'
          result = { result: 'Internal Cleanup Underway' }
          body result
        end

        # run the cleanup process manually from a server admin via xadm
        ################
        post '/cleanup' do
          log_info "Starting manual server cleanup by #{session[:admin]}"

          thr = Thread.new { cleanup_versions }
          thr.name = 'Manual Cleanup Thread'
          result = { result: 'Manual Cleanup Underway' }
          body result
        end

        # force an update of the client data
        ################
        post '/update-client-data' do
          log_info "Force update of client-data by #{session[:admin]}"

          thr = Thread.new { update_client_data }
          thr.name = 'Manual Client Data Update Thread'
          result = { result: 'Client Data Update underway' }
          body result
        end

        # force log rotation
        ################
        post '/rotate-logs' do
          log_info "Force log rotation by #{session[:admin]}"

          thr = Thread.new { Xolo::Server::Log.rotate_logs force: true }
          thr.name = 'Manual Log Rotation Thread'
          result = { result: 'Log rotation underway' }
          body result
        end

        # set the log level
        ################
        post '/set-log-level' do
          request.body.rewind
          payload = parse_json request.body.read
          level = payload[:level]

          Xolo::Server.set_log_level level, admin: session[:admin]

          result = { result: "Log level set to #{level}" }
          body result
        end

        # Shutdown the server gracefully
        # stop accepting new requests
        # wait for all queues and threads to finish, including:
        #  the cleanup timer task & mutex
        #  the log rotation timer task & mutex
        #  the pkg deletion pool
        #  the object locks
        #  the progress streams, including this one, which will be the last thing to finish
        ################
        post '/shutdown-server' do
          request.body.rewind
          payload = parse_json request.body.read
          restart = payload[:restart]

          # for streamed responses, the with_streaming block must
          # be the last thing in the route
          with_streaming do
            # give the stream a chance to get started
            sleep 2
            shutdown_server restart
          end
        end

      end # module maint

    end #  Routes

  end #  Server

end # module Xolo
