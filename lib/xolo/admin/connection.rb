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

  module Admin

    # connection to the xolo server from xadm
    module Connection

      # Constants
      ##############################
      ##############################

      TIMEOUT = 300
      OPEN_TIMEOUT = 10

      PING_ROUTE = '/ping'
      PING_RESPONSE = 'pong'

      LOGIN_ROUTE = '/auth/login'

      # Module methods
      ##############################
      ##############################

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # Instance Methods
      ##############################
      ##############################

      # Authenticate to the Xolo server and get a session token
      # (maintained by Faraday via the Xolo::Admin::CookieJar middleware)
      #
      ##############
      def login
        return if cmd_details[:no_login]

        hostname = config.hostname
        admin = config.admin
        pw = fetch_pw
        xadm = Xolo::Admin::EXECUTABLE_FILENAME

        raise Xolo::MissingDataError, "No xolo server hostname. Please run '#{xadm} config'" unless hostname
        raise Xolo::MissingDataError, "No xolo admin username. Please run '#{xadm} config'" unless admin

        payload = { admin: admin, password: pw }

        # provide the hostname to make a persistent Faraday connection object
        # so in the future we just call server_cnx with no hostname to get the same
        # connection object
        resp = server_cnx.post Xolo::Admin::Connection::LOGIN_ROUTE, payload
        return if resp.success?

        case resp.status
        when 401
          raise Xolo::AuthenticationError, resp.body[:error]
        else
          raise Xolo::ServerError, "#{resp.status}: #{resp.body}"
        end
      end

      # @pararm host [String] an alternate hostname to use, defaults to config.hostname
      #
      # @return [URI] The server base URL
      #################
      def server_url(host: nil)
        @server_url = nil if host
        return @server_url if @server_url

        @server_url = URI.parse "https://#{host || config.hostname}"
      end

      # A connection for requests without any file uploads
      #
      # None of our GET routes expected any request body, so it doesn't matter if
      # its set to be JSON.
      #
      # For our POST routes that dont upload files (e.g. setloglevel), the request
      # body, if any, will be JSON.
      #
      # @param host [String] The hostname of the Xolo server. Must be provided the
      #   first time this is called (usually for logging in)
      #
      # @return [Faraday::Connection]
      ##################################
      def server_cnx(host: nil)
        @server_cnx = nil if host
        return @server_cnx if @server_cnx

        @server_cnx = Faraday.new(server_url(host: host)) do |cnx|
          cnx.options[:timeout] = TIMEOUT
          cnx.options[:open_timeout] = OPEN_TIMEOUT

          cnx.request :json

          cnx.use Xolo::Admin::CookieJar

          cnx.response :json, parser_options: { symbolize_names: true }
          cnx.response :raise_error

          cnx.adapter :net_http
        end
      end

      # A connection for POST requests with file uploads
      #
      # The request body will be multipart/url-encoded
      # and authentication is required
      #
      # @param host [String] The hostname of the Xolo server. Must be provided the
      #   first time this is called (usually for logging in)
      #
      # @return [Faraday::Connection]
      ##################################
      def upload_cnx(host: nil)
        @upload_cnx = nil if host
        return @upload_cnx if @upload_cnx

        @upload_cnx = Faraday.new(server_url(host: host)) do |cnx|
          cnx.options[:timeout] = TIMEOUT
          cnx.options[:open_timeout] = OPEN_TIMEOUT

          cnx.request :multipart
          cnx.request :url_encoded

          cnx.use Xolo::Admin::CookieJar

          cnx.response :json, parser_options: { symbolize_names: true }
          cnx.response :raise_error

          cnx.adapter :net_http
        end
      end

      # Handle errors from the Xolo Server
      #
      #######################
      def handle_server_error(err)
        case err
        when Faraday::Error
          raise err, parse_json(err.response[:body])[:error]
        else
          raise err
        end
      end

    end # module Connection

  end # module Admin

end # module Xolo
