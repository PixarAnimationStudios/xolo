# Copyright 2018 Pixar
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

module Xolo

  module Server

    # The sinatra HTTPS server
    class App < Sinatra::Base

      # Server-wide constants
      #####################################

      JSON_CONTENT_TYPE = 'application/json'.freeze

      register Sinatra::Namespace
      helpers Sinatra::CustomLogger

      # quicker access to the configuration
      def self.config
        Xolo::Server.config
      end

      def self.run!(log_level = config.log_level)
        prep_to_run log_level

        D3.logger.info 'Starting Server'

        super({}) do |svr|
          svr.ssl = true
          svr.ssl_options = {
            cert_chain_file: config.ssl_cert,
            private_key_file: config.ssl_key,
            verify_peer: config.ssl_verify
          }
        end # super do
      end # run!

      def self.prep_to_run(log_level)
        configure do
          set :show_exceptions, :after_handler if development?

          set :server, :thin
          set :bind, '0.0.0.0'
          set :port, config.port

          set :logger, Xolo::Server::Log.startup(log_level)

          # TODO: when I write an admin UI
          # enable :static
          # set :root, File.dirname(__FILE__)

          # enable :sessions
          # set :session_secret, SecureRandom.hex(64)
          # set :sessions, expire_after: config.session_expiration

          # Using Pool keeps the data on the server, only a session id
          # is passed back and forth. That way when we logout/delete a session
          # it is invalidated regardless of expiration.
          use(Rack::Session::Pool,
              key: Xolo::SESSION_KEY,
              expire_after: config.session_expiration,
              secret: SecureRandom.hex(64))
        end # configure do

        Xolo::Server::Helpers::Jamf.connect_to_jamf
        Xolo::Server::Title.load_data_store
        Xolo::Server::Version.load_data_store
      end # self.prep_to_run(log_level)

    end # class App

  end # module server

end # module Xolo

require 'xolo/server/app/log'

# d3 api
require 'xolo/server/app/api'

# d3 patch sourch

# d3 admin pages
