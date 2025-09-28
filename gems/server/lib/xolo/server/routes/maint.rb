# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
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
        extend Sinatra::Extension

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # when this module is extended
        def self.extended(extender)
          Xolo.verbose_extend extender, self
        end

        # Threads
        ##########
        get '/maint/threads' do
          body Xolo::Server.thread_info
        end

        # State
        ##########
        get '/maint/state' do
          require 'concurrent/version'
          uptime_secs = (Time.now - Xolo::Server.start_time).to_i

          state = {
            start_time: Xolo::Server.start_time,
            uptime: uptime_secs.pix_humanize_secs,
            uptime_secs: uptime_secs,
            app_env: Xolo::Server.app_env,
            data_dir: Xolo::Server::DATA_DIR,
            log_file: Xolo::Server::Log::LOG_FILE,
            log_level: Xolo::Server::Log::LEVELS[Xolo::Server.logger.level],
            ruby_version: RUBY_VERSION,
            gems: {
              xolo_version: Xolo::VERSION,
              ruby_jss_version: Jamf::VERSION,
              windoo_version: Windoo::VERSION,
              sinatra_version: Sinatra::VERSION,
              thin_version: Thin::VERSION::STRING,
              concurrent_ruby_version: Concurrent::VERSION,
              faraday_version: Faraday::VERSION
            },
            config: Xolo::Server.config.to_h_private
          }

          if params[:extended]
            state[:gem_path] = Gem.paths.path
            state[:load_path] = $LOAD_PATH
            state[:object_locks] = Xolo::Server.object_locks
            state[:pkg_deletion_pool] = Xolo::Server::Version.pkg_deletion_pool_info
            state[:threads] = Xolo::Server.thread_info
          end

          body state
        end

        # run the cleanup process from the internal timer task
        # The before filter will ensure the request came from the server itself.
        # with a valid internal auth token.
        ################
        post '/maint/cleanup-internal' do
          log_info 'Starting internal cleanup'
          session[:admin] = 'Automated Cleanup'

          thr = Thread.new { run_cleanup }
          thr.name = 'Internal Cleanup Thread'
          result = { result: 'Internal Cleanup Underway' }
          body result
        end

        # run the cleanup process manually from a server admin via xadm
        ################
        post '/maint/cleanup' do
          log_info "Starting manual server cleanup by #{session[:admin]}"

          session[:admin] = "Cleanup by #{session[:admin]}"
          thr = Thread.new { run_cleanup }
          thr.name = 'Manual Cleanup Thread'
          result = { result: 'Manual Cleanup Underway' }
          body result
        end

        # force an update of the client data
        ################
        post '/maint/update-client-data' do
          log_info "Force update of client-data by #{session[:admin]}"
          log_debug "Gem Paths: #{Gem.paths.inspect}"

          thr = Thread.new { update_client_data }
          thr.name = 'Manual Client Data Update Thread'
          result = { result: 'Client Data Update underway' }
          body result
        end

        # force log rotation
        ################
        post '/maint/rotate-logs' do
          log_info "Force log rotation by #{session[:admin]}"

          thr = Thread.new { Xolo::Server::Log.rotate_logs force: true }
          thr.name = 'Manual Log Rotation Thread'
          result = { result: 'Log rotation underway' }
          body result
        end

        # set the log level
        ################
        post '/maint/set-log-level' do
          request.body.rewind
          payload = parse_json request.body.read
          level = payload[:level]

          log_info "Setting log level to #{level} by #{session[:admin]}"
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
        post '/maint/shutdown-server' do
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
