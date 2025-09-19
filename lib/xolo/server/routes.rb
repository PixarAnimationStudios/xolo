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
        if Xolo::Server.shutting_down? && !request.path.start_with?('/streamed_progress/')
          halt 503, { status: 503, error: 'Server is shutting down' }
        end

        adm = session[:admin] ? ", admin '#{session[:admin]}'" : Xolo::BLANK
        log_info "Processing #{request.request_method} #{request.path} from #{request.ip}#{adm}"

        log_debug "Session in before-filter: #{session.inspect}"

        # these routes don't need an auth'd session
        log_debug "Checking if request path '#{request.path}' is in NO_AUTH_ROUTES or NO_AUTH_PREFIXES"
        break if Xolo::Server::Helpers::Auth::NO_AUTH_ROUTES.include? request.path
        break if Xolo::Server::Helpers::Auth::NO_AUTH_PREFIXES.any? { |pfx| request.path.start_with? pfx }

        # these routes are expected to be called by the xolo server itself
        log_debug "Checking if request path '#{request.path}' is in INTERNAL_ROUTES"
        break if Xolo::Server::Helpers::Auth::INTERNAL_ROUTES.include?(request.path) && valid_internal_auth_token?

        # these routes are for server admins only, and require an authenticated session
        log_debug "Checking if request path '#{request.path}' is in SERVER_ADMIN_ROUTES"
        break if Xolo::Server::Helpers::Auth::SERVER_ADMIN_ROUTES.include?(request.path) && valid_server_admin?

        # If here, we must have a session cookie marked as 'authenticated'
        halt 401, { status: 401, error: 'You must log in to the Xolo server' } unless session[:authenticated]
      end

      # error process
      ##############
      error do
        log_debug 'Running error filter'

        resp_body = { status: response.status, error: env['sinatra.error'].message }
        body resp_body
      end

      # post-process
      # Convert the body to JSON unless @no_json is set
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
        # can't
      end

      # Ping
      ##########
      get '/ping' do
        @no_json = true
        body 'pong'
      end

      # The streamed progress updates
      # The stream_file param should be in the URL query, i.e.
      # "/streamed_progress/?stream_file=<url-escaped path to file>"
      #
      ################
      get '/streamed_progress/' do
        log_debug "Starting progress stream from file: #{params[:stream_file]}"
        # make note that this Server instance is just streaming from a file
        # not acuatlly processing anything.
        @streaming_from_file = true

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
        # Xolo::Server::Helpers::Maintenance.post_to_start_cleanup force: true
        # result = { result: 'posted to start cleanup' }

        # send_email(
        #   to: 'xolo@pixar.com',
        #   subject: 'Test Email from Xolo Server',
        #   msg: 'This is a test email from the Xolo Server'
        # )
        # result = { result: 'message sent' }

        # client_data_testing
        # update_client_data

        result = { result: 'test' }

        body result
      end

    end #  Routes

  end #  Server

end # module Xolo
