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
#

# frozen_string_literal: true

# main module
module Xolo

  module Server

    # The actual server application - a Sinatra/Thin HTTPS server
    class App < Sinatra::Base

      # Extensions & Helpers
      ##############################
      ##############################

      register Xolo::Server::Routes
      register Xolo::Server::Routes::Auth
      register Xolo::Server::Routes::JamfPro
      register Xolo::Server::Routes::TitleEditor
      register Xolo::Server::Routes::Titles
      register Xolo::Server::Routes::Versions
      register Xolo::Server::Routes::Uploads

      helpers Xolo::Core::Constants
      helpers Xolo::Core::JSONWrappers
      helpers Xolo::Server::Helpers::Log
      helpers Xolo::Server::Helpers::Auth
      helpers Xolo::Server::Helpers::JamfPro
      helpers Xolo::Server::Helpers::TitleEditor
      helpers Xolo::Server::Helpers::Titles
      helpers Xolo::Server::Helpers::Versions
      helpers Xolo::Server::Helpers::FileTransfers
      helpers Xolo::Server::Helpers::PkgSigning
      helpers Xolo::Server::Helpers::ProgressStreaming
      helpers Xolo::Server::Helpers::ClientData

      # Sinatra setup
      ##############################
      ##############################

      ##########
      configure do
        set :server, :thin
        set :bind, '0.0.0.0'
        set :port, 443

        set :dump_errors, true
        disable :show_exceptions

        # logger = Xolo::Server.logger
        # logger.level = development? ? Logger::DEBUG : Logger::INFO
        # set :logger, logger

        enable :sessions
        set :session_secret, SecureRandom.hex(64)
        set :protection, session: true
        set :sessions, expire_after: 3600
      end

      ###############
      configure :development do
        require 'pp'
      end

      #############
      configure :production do
        set :show_exceptions, false
      end

      # Run !
      ################
      def self.run!(**options, &block)
        setup

        super do |server|
          server.ssl = true
          server.ssl_options = {
            cert_chain_file: Xolo::Server::Configuration::SSL_CERT_FILE.to_s,
            private_key_file: Xolo::Server::Configuration::SSL_KEY_FILE.to_s,
            verify_peer: false
          }
        end # super do
      end

      # Do some setup as we start the server
      ##########################
      def self.setup
        Xolo::Server::DATA_DIR.mkpath
        Xolo::Server::Title::TITLES_DIR.mkpath
        setup_ssl
        Xolo::Server.start_time = Time.now
        Xolo::Server.logger.info 'Starting Up'
      end

      ##########################
      def self.setup_ssl
        Xolo::Server::Configuration::SSL_DIR.mkpath
        Xolo::Server::Configuration::SSL_DIR.chmod 0o700
        Xolo::Server::Configuration::SSL_CERT_FILE.pix_save Xolo::Server.config.ssl_cert
        Xolo::Server::Configuration::SSL_CERT_FILE.chmod 0o600
        Xolo::Server::Configuration::SSL_KEY_FILE.pix_save Xolo::Server.config.ssl_key
        Xolo::Server::Configuration::SSL_KEY_FILE.chmod 0o600
      end

      ######################
      def debug?
        Xolo::Server.debug?
      end

    end # class App

  end # Server

end #  Xolo
