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

      # The server base URL
      #
      def server_url(host: nil)
        @server_url = nil if host
        return @server_url if @server_url

        @server_url = URI.parse "https://#{host || config.hostname}"
      end

      # A possibly-authenticated connection for GET requests, or POST requests
      # without any file uploads
      #
      # For routes that aren't protected, the user and pw are ignored.
      #
      # None of our GET routes expected any request body, so it doesn't matter if
      # its set to be JSON.
      #
      # For our POST routes that dont upload files (e.g. setloglevel), the request
      # body, if any, will be JSON.
      #
      # @param user [String] The username for authentication
      # @param pw [String] The password for authentication
      # @param test [Boolean] Use the test s3po server
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
          cnx.response :json, parser_options: { symbolize_names: true }
          cnx.adapter :net_http
        end
      end

      # An authenticated connection for POST requests with file uploads
      #
      # User and pw can be omitted (left as nil) when this is used
      # from a pre-approved host
      #
      # The request body will be multipart/url-encoded
      # and authentication is required
      #
      # @param user [String] The username for authentication
      # @param pw [String] The password for authentication
      # @param test [Boolean] Use the test s3po server
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
          cnx.response :json, parser_options: { symbolize_names: true }
          cnx.adapter :net_http
        end
      end

    end # module Connection

  end # module Admin

end # module Xolo
