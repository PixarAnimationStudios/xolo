# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
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
      register Xolo::Server::Routes::Maint
      register Xolo::Server::Routes::JamfPro
      register Xolo::Server::Routes::TitleEditor
      register Xolo::Server::Routes::Titles
      register Xolo::Server::Routes::Versions
      register Xolo::Server::Routes::Uploads

      helpers Xolo::Core::Constants
      helpers Xolo::Core::JSONWrappers
      helpers Xolo::Server::Helpers::Log
      helpers Xolo::Server::Helpers::Notification
      helpers Xolo::Server::Helpers::Auth
      helpers Xolo::Server::Helpers::JamfPro
      helpers Xolo::Server::Helpers::TitleEditor
      helpers Xolo::Server::Helpers::Titles
      helpers Xolo::Server::Helpers::Versions
      helpers Xolo::Server::Helpers::FileTransfers
      helpers Xolo::Server::Helpers::PkgSigning
      helpers Xolo::Server::Helpers::ProgressStreaming
      helpers Xolo::Server::Helpers::ClientData
      helpers Xolo::Server::Helpers::Maintenance

      # Sinatra setup
      ##############################
      ##############################

      ##########
      configure do
        Xolo::Server.logger.debug 'Configuring Server App'
        set :server, :thin
        set :bind, '0.0.0.0'
        set :port, 443

        set :dump_errors, true
        disable :show_exceptions

        # Logging is handled by the Xolo::Server::Log module

        enable :sessions
        set :session_secret, SecureRandom.hex(64)
        set :protection, session: true
        set :sessions, expire_after: Xolo::Server::Constants::SESSION_EXPIRE_AFTER
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
        Xolo::Server.logger.info 'Server App Starting Up'

        setup

        super do |server|
          server.ssl = true
          # verify peer is false so that we don't require client certs
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

        Xolo::Server::Log.log_rotation_timer_task.execute
        Xolo::Server::Helpers::Maintenance.cleanup_timer_task.execute

        # Disable warnings in logs about known scope bug in Jamf Classic API
        Jamf::Scopable::Scope.do_not_warn_about_policy_scope_bugs
      end

      ##########################
      def self.setup_ssl
        Xolo::Server.logger.debug 'Setting up SSL certificates'
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
