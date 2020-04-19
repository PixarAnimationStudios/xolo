
module Xolo

  module Server

    # The sinatra server
    class App < Sinatra::Base

      # create an API route-condition called api_admin_only
      #
      # Use this condition in routes that are only available to d3admin
      # otherwise d3 clients can see them too
      # e.g.
      #
      # delete '/title/:id', api_admin_only: true
      # get '/some-report/', api_admin_only: true
      # post '/title/:id/version/', api_admin_only: true
      #
      # See http://sinatrarb.com/intro.html#Conditions
      #
      set(:api_admin_only) do |admin_only|
        condition do
          break unless admin_only
          if Xolo::Server::Helpers::Auth::ADMIN_ROLE == session[:role]
            D3.logger.debug "Accepted Admin session from #{whodat} for #{request.request_method} #{request.path_info}"
            return
          end

          halt 401, error_response("Role '#{session[:role]}' is not allowed to access this resource")
        end # condition
      end # set :allowed_roles

      namespace API_V1_ROUTE_BASE do
        # the API routes

        # filters for the API routes
        ###########################

        before do
          content_type JSON_CONTENT_TYPE
          D3.logger.debug "Processing #{request.request_method} #{request.path_info} for #{session[:user] || :unknown}@#{request.ip}"
          # all api routes other than the session route must be logged in
          break if request.path_info.start_with? SESSION_ROUTE
          halt_if_not_logged_in!
        end

        not_found do
          error_response "Not Found: #{request.path_info}"
        end

        error do
          error_message = env['sinatra.error'].message.dup
          error_message << "\nBacktrace:"
          env['sinatra.error'].backtrace.each { |l| error_message << "\n..#{l}" }
          halt 500, error_response(error_message)
        end # error do
      end # namespace

    end # class App

  end # module server

end # module Xolo

require 'xolo/server/app/api/routes/sessions'
require 'xolo/server/app/api/routes/titles'
require 'xolo/server/app/api/routes/versions'
require 'xolo/server/app/api/routes/categories'
require 'xolo/server/app/api/routes/packages'
require 'xolo/server/app/api/routes/scripts'
require 'xolo/server/app/api/routes/policies'
require 'xolo/server/app/api/routes/computer_groups'
require 'xolo/server/app/api/routes/test'
