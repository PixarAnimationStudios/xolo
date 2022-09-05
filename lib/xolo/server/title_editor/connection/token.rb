# Copyright 2022 Pixar
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

module Xolo

  module Server 

    module TitleEditor

      class Connection

        # A token used for a connection to either API
        class Token

          AUTH_RSRC = 'auth'

          NEW_TOKEN_RSRC = "#{AUTH_RSRC}/tokens"

          REFRESH_RSRC = "#{AUTH_RSRC}/keepalive"

          CURRENT_STATUS_RSRC = "#{AUTH_RSRC}/current"

          # Seconds before expiration that the token will automatically refresh
          REFRESH_BUFFER = 300

          # Used bu the last_refresh_result method
          REFRESH_RESULTS = {
            refreshed: 'Refreshed',
            refreshed_pw: 'Refresh failed, but new token created with cached pw',
            refresh_failed: 'Refresh failed, could not create new token with cached pw',
            refresh_failed_no_pw_fallback: 'Refresh failed, but pw_fallback was false',
            expired_refreshed: 'Expired, but new token created with cached pw',
            expired_failed: 'Expired, could not create new token with cached pw',
            expired_no_pw_fallback: 'Expired, but pw_fallback was false'
          }.freeze

          # @return [String] The user who generated this token
          attr_reader :user
          
          # @return [Integer] The user id of the @user on the server
          attr_reader :user_id

          # @return [Array<String>] The permissions of the @user
          attr_reader :scope
          alias permissions scope
          
          # @return [String] the SSL version being used
          attr_reader :ssl_version

          # @return [Boolean] are we verifying SSL certs?
          attr_reader :verify_cert
          alias verify_cert? verify_cert

          # @return [Hash] the ssl version and verify cert, to pass into faraday connections
          attr_reader :ssl_options

          # @return [String] The token data
          attr_reader :token
          alias token_string token
          alias auth_token token

          # @return [URI] The base API url, e.g. https://yourserver.appcatalog.jamfcloud.com
          attr_reader :base_url

          # @return [Time] when was this Xolo::TitleServer::Connection::Token originally created?
          attr_reader :creation_time
          alias login_time creation_time

          # @return [Time] when was this token last refreshed?
          attr_reader :last_refresh

          # @return [Time]
          attr_reader :expires
          alias expiration expires

          # @return [Boolean] does this token automatically refresh itself before
          #   expiring?
          attr_reader :keep_alive
          alias keep_alive? keep_alive

          # @return [Boolean] Should the provided passwd be cached in memory, to be
          #   used to generate a new token, if a normal refresh fails?
          attr_reader :pw_fallback
          alias pw_fallback? pw_fallback

          # @return [Faraday::Response] The response object from instantiating
          #   a new Token object by creating a new token or validating a token 
          #   string. This is not updated when refreshing a token, only when
          #   calling Token.new
          attr_reader :creation_http_response

          # @return [Time] The time the server created the token
          attr_reader :server_creation_time 

          # @return [String] The tenantID of this server connection
          attr_reader :tenantId
          alias tenant_id tenantId

          # @return [String] The fully qualified hostname of the server
          #   that generated this token
          attr_reader :domain

          # @param params [Hash] The data for creating and maintaining the token
          #
          # @option params [String, URI] base_url: The url for the Jamf Pro server
          #   including host and port, e.g. 'https://yourserver.appcatalog.jamfcloud.com'
          #
          # @option params [String] user: (see Connection#initialize)
          #
          # @option params [String] token_string: An existing valid token string.
          #   If provided, no need to provide 'user', which will be read from the 
          #   server. If pw_fallback is true (the default) you will also need to provide
          #   the password for the user who created the token in the pw: parameter. 
          #   If you don't, pw_fallback will be false even if you set it to true explicitly.
          #
          # @option params [String] pw: (see Connection#initialize)
          #
          # @option params [Integer] timeout: The http timeout for communication
          #   with the server. This is only used for token-related communication, not
          #   general API usage, and so need not be the same as that for the
          #   connection that uses this token.
          #
          # @option params [Boolean] keep_alive: (see Connection#connect)
          #
          # @option params [Boolean] pw_fallback: (see Connection#connect)
          #
          # @option params [String, Symbol] ssl_version: (see Connection#connect)
          #
          # @option params [Boolean] verify_cert: (see Connection#connect)
          #
          ###########################################
          def initialize(**params)
            @valid = false
            parse_params(**params)

            if params[:token_string]
              @pw_fallback = false unless @pw
              @creation_http_response = init_from_token_string params[:token_string]

            elsif @user && @pw
              @creation_http_response = init_from_pw

            else
              raise ArgumentError, 'Must provide either user: & pw: or token_string:'
            end

            start_keep_alive if @keep_alive
            @creation_time = Time.now
          end # init

          # Initialize from password
          # @return [Faraday::Response] the response from checking the status,
          #   which might be used to set @creation_http_response
          #################################
          def init_from_pw
            resp = token_connection(NEW_TOKEN_RSRC).post
            
            if resp.success?
              @token = resp.body[:token]
              parse_token_status 
              @last_refresh = Time.now
              resp
            elsif resp.status == 401
              raise Xolo::AuthenticationError, 'Incorrect user name or password'
            else
              # TODO: better error reporting here
              puts
              puts resp.status
              puts resp.body
              puts
              raise Xolo::ConnectionError, "An error occurred while authenticating: #{resp.body}"
            end
          ensure
            @pw = nil unless @pw_fallback
          end # init_from_pw

          # Initialize from token string
          # @return [Faraday::Response] the response from checking the status,
          #   which might be used to set @creation_http_response
          #################################
          def init_from_token_string(str)
            @token = str
            parse_token_status
            
            # we now know the @user who created the token string.
            # if we were given a pw and expect to use it, call init_from_pw
            # to validate it by getting a fresh token
            return init_from_pw if @pw && @pw_fallback

            # use this token to get a fresh one with the full 
            # 15 min lifespan
            refresh
          end # init_from_token_string

          #################################
          def host
            base_url.host
          end

          # @return [Integer]
          #################################
          def port
            base_url.port
          end

          # @return [Boolean]
          #################################
          def expired?
            return unless @expires

            Time.now >= @expires
          end

          # when is the next rerefresh going to happen, if we are set to keep alive?
          #
          # @return [Time, nil] the time of the next scheduled refresh, or nil if not keep_alive?
          def next_refresh
            return unless keep_alive?

            @expires - REFRESH_BUFFER
          end

          # how many secs until the next refresh?
          # will return 0 during the actual refresh process.
          #
          # @return [Float, nil] Seconds until the next scheduled refresh, or nil if not keep_alive?
          #
          def secs_to_refresh
            return unless keep_alive?

            secs = next_refresh - Time.now
            secs.negative? ? 0 : secs
          end

          # Returns e.g. "1 week 6 days 23 hours 49 minutes 56 seconds"
          #
          # @return [String, nil]
          def time_to_refresh
            return unless keep_alive?

            Xolo.humanize_secs secs_to_refresh
          end

          # @return [Float]
          #################################
          def secs_remaining
            return unless @expires

            @expires - Time.now
          end

          # @return [String] e.g. "1 week 6 days 23 hours 49 minutes 56 seconds"
          #################################
          def time_remaining
            return unless @expires

            Xolo.humanize_secs secs_remaining
          end

          # @return [Boolean]
          #################################
          def valid?
            @valid =
              if expired?
                false
              elsif !@token
                false
              else
                token_connection(CURRENT_STATUS_RSRC, token: token).post.success?
              end
          end

          # What happened the last time we tried to refresh?
          # See REFRESH_RESULTS
          #
          # @return [String, nil] result or nil if never refreshed
          #################################
          def last_refresh_result
            REFRESH_RESULTS[@last_refresh_result]
          end

          # Use this token to get a fresh one. If a pw is provided
          # try to use it to get a new token if a proper refresh fails.
          #
          # @param pw [String] Optional password to use if token refresh fails.
          #   Must be the correct passwd or the token's user (obviously)
          #
          # @return [Faraday::Response] the response from checking the status,
          #   which might be used to set @creation_http_response
          #
          #################################
          def refresh
            # already expired?
            if expired?
              # try the passwd if we have it
              return refresh_with_pw(:expired_refreshed, :expired_failed) if @pw

              # no passwd fallback? no chance!
              @last_refresh_result = :expired_no_pw_fallback
              raise Xolo::InvalidTokenError, 'Token has expired'
            end

            # Now try a normal refresh of our non-expired token
            refresh_resp = token_connection(REFRESH_RSRC, token: token).post

            if refresh_resp.success?
              @token = refresh_resp.body[:token]
              parse_token_status 
              @last_refresh = Time.now
              return refresh_resp
            end

            # if we're here, the normal refresh failed, so try the pw
            return refresh_with_pw(:refreshed_pw, :refresh_failed) if @pw

            # if we're here, no pw = no chance!
            @last_refresh_result = :refresh_failed_no_pw_fallback
            raise Xolo::InvalidTokenError, 'An error occurred while refreshing the token'
          end
          alias keep_alive refresh

          # Make this token invalid
          #################################
          def invalidate
            stop_keep_alive
            @valid = false
            @token = nil
            @pw = nil
          end
          alias destroy invalidate

          # creates a thread that loops forever, sleeping most of the time, but
          # waking up every 60 seconds to see if the token is expiring in the
          # next REFRESH_BUFFER seconds.
          #
          # If so, the token is refreshed, and we keep looping and sleeping.
          #
          # Sets @keep_alive_thread to the Thread object
          #
          # @return [void]
          #################################
          def start_keep_alive
            return if @keep_alive_thread
            raise 'Token expired, cannot refresh' if expired?

            @keep_alive_thread =
              Thread.new do
                loop do
                  sleep 60
                  begin
                    next if secs_remaining > REFRESH_BUFFER

                    refresh
                  rescue
                    # TODO: Some kind of error reporting
                    next
                  end
                end # loop
              end # thread
          end # start_keep_alive

          # Kills the @keep_alive_thread, if it exists, and sets
          # @keep_alive_thread to nil
          #
          # @return [void]
          #
          def stop_keep_alive
            return unless @keep_alive_thread

            @keep_alive_thread.kill if @keep_alive_thread.alive?
            @keep_alive_thread = nil
          end

          # Private instance methods
          #################################
          private

          # set values from params & defaults
          ###########################################
          def parse_params(**params)
            # This process of deleting suffixes will leave in place any
            # URL paths before the the CAPI_RSRC_BASE or JPAPI_RSRC_BASE
            # e.g.  https://my.jamf.server:8443/some/path/before/api
            # as is the case at some on-prem sites.
            baseurl = params[:base_url].to_s.dup
            baseurl.delete_suffix! '/'
            @base_url = URI.parse baseurl

            @timeout = params[:timeout] || Xolo::Server::TitleEditor::Connection::DFT_TIMEOUT

            @user = params[:user]

            # @pw will be deleted after use if pw_fallback is false
            # It is stored as base64 merely for visual security in irb sessions
            # and the like.
            @pw = Base64.encode64 params[:pw] if params[:pw].is_a? String

            @pw_fallback = params[:pw_fallback].instance_of?(FalseClass) ? false : true

            @ssl_version = params[:ssl_version] || Jamf::Connection::DFT_SSL_VERSION
            @verify_cert = !(params[:verify_cert] == false)
            @ssl_options = { version: @ssl_version, verify: @verify_cert }

            @keep_alive = !(params[:keep_alive] == false)
          end

          # Parse the response from the CURRENT_STATUS_RSRC to set 
          # ome attributes from the current token
          # 
          # @return [Faraday::Response] the response from checking the status,
          #   which might be used to set @creation_http_response
          ####################################
          def parse_token_status
            resp = token_connection(CURRENT_STATUS_RSRC, token: token).post
            raise Xolo::InvalidTokenError, 'Token is not valid' unless resp.success?

            @server_creation_time = Time.at resp.body[:iat]
            @expires = Time.at resp.body[:exp]
            @user = resp.body[:user]
            @user_id = resp.body[:id]
            @scope = resp.body[:scope]
            @domain = resp.body[:domain]
            @tenantId = resp.body[:tenantId]
            @valid = true

            resp
          end

          # refresh a token using the pw cached when @pw_fallback is true
          #
          # @param success [Sumbol] the key from REFRESH_RESULTS to use when successful
          # @param failure [Sumbol] the key from REFRESH_RESULTS to use when not successful
          # @return [Faraday::Response] the response from checking the status,
          #   which might be used to set @creation_http_response
          #################################
          def refresh_with_pw(success, failure)
            resp = init_from_pw
            @last_refresh_result = success
            resp
          rescue => e
            @last_refresh_result = failure
            raise e, "#{e}. Status: :#{REFRESH_RESULTS[failure]}"
          end

          # a generic, one-time Faraday connection for token
          # acquision & manipulation
          #################################
          def token_connection(rsrc, token: nil)
            Faraday.new("#{base_url}/#{rsrc}", ssl: @ssl_options) do |con|
              con.request :json
              con.response :json, parser_options: { symbolize_names: true }
              con.options[:timeout] = @timeout
              con.options[:open_timeout] = @timeout
              if token
                con.authorization :Bearer, token
              else
                con.basic_auth @user, Base64.decode64(@pw)
              end
              con.adapter :net_http
            end # Faraday.new
          end # token_connection

        end # class Token

      end # class Connection

    end # module TitleEditor

  end # module Server

end # module Jamf
