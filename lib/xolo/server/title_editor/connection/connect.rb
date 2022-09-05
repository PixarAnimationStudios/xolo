### Copyright 2022 Pixar
###
###    Licensed under the Apache License, Version 2.0 (the "Apache License")
###    with the following modification; you may not use this file except in
###    compliance with the Apache License and the following modification to it:
###    Section 6. Trademarks. is deleted and replaced with:
###
###    6. Trademarks. This License does not grant permission to use the trade
###       names, trademarks, service marks, or product names of the Licensor
###       and its affiliates, except as required to comply with Section 4(c) of
###       the License and to reproduce the content of the NOTICE file.
###
###    You may obtain a copy of the Apache License at
###
###        http://www.apache.org/licenses/LICENSE-2.0
###
###    Unless required by applicable law or agreed to in writing, software
###    distributed under the Apache License with the above modification is
###    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
###    KIND, either express or implied. See the Apache License for the specific
###    language governing permissions and limitations under the Apache License.
###
###

# frozen_string_literal: true

module Xolo

  module Server 

    module TitleEditor

      class Connection

        # This module defines constants and methods used for processing the connection
        # parameters, acquiring passwords and tokens, and creating the underlying Faraday
        # connection objects to the Title Editor API. It also defines the disconnection
        # methods
        #############################################
        module Connect

          def self.included(includer)
            Xolo.verbose_include(includer, self)
          end

          # Connect to the both the Classic and Jamf Pro APIs
          #
          # IMPORTANT: http (non-SSL, unencrypted) connections are not allowed.
          #
          # The first parameter may be a URL (must be https) from which
          # the host & port will be used, and if present, the user and password
          # E.g.
          #   connect 'https://myuser:pass@host.domain.edu:8443'
          #
          # which is the same as:
          #   connect host: 'host.domain.edu', port: 8443, user: 'myuser', pw: 'pass'
          #
          # When using a URL, other parameters below may be specified, however
          # host: and port: parameters will be ignored, since they came from the URL,
          # as will user: and :pw, if they are present in the URL. If the URL doesn't
          # contain user and pw, they can be provided via the parameters, or left
          # to default values.
          #
          # ### Passwords
          #
          # The pw: parameter also accepts the symbols :prompt, and :stdin[X]
          #
          # If :prompt, the user is promted on the commandline to enter the password
          # for the :user.
          #
          # If pw: is omitted, and running from an interactive terminal, the user is
          # prompted as with :prompt
          #
          # ### Tokens
          # Instead of a user and password, you may specify a valid 'token:', which is
          # either:
          #
          # A Xolo::Server::TitleEditor::Connection::Token object, which can be extracted from an active
          # Xolo::Server::TitleEditor::Connection via its #token method
          #
          # or
          #
          # A valid token string e.g. "eyJhdXR...6EKoo" from any source can also be used.
          #
          # When using an existing token or token string, the username used to create
          # the token will be read from the server. However, if you don't also provide
          # the users password using the pw: parameter, then the pw_fallback option
          # will always be false.
          #
          # ### Default values
          #
          # Any values available via Xolo.config will be used if they are not provided
          # in the parameters. See Xolo::Configuration. If there are no config values
          # then a built-in default is used if available.
          #
          # @param url[String] The URL to use for the connection. Must be 'https'.
          #   The host, port, and (if provided), user & password will be extracted.
          #   Any of those params explicitly provided will be ignored if present in
          #   the url
          #
          # @param params[Hash] the keyed parameters for connection.
          #
          # @option params :host[String] the hostname of the Title Editor server, required
          #   if not defined in Xolo.config
          #
          # @option params :user[String] a JSS user who has API privs, required if not
          #   defined in Jamf::CONFIG
          #
          # @option params :pw[String, Symbol] The user's password, or :prompt
          #   If :prompt, the user is promted on the commandline to enter the password
          #
          # @option params :port[Integer] the port number to connect with, defaults
          #   to 443
          #
          # @option params :ssl_version[String, Symbol] The SSL version to use. Default
          #   is TLSv1_2
          #
          # @option params :verify_cert[Boolean] should SSL certificates be verified.
          #   Defaults to true.
          #
          # @option params :open_timeout[Integer] the number of seconds to wait for an
          #   initial response, defaults to 60
          #
          # @option params :timeout[Integer] the number of seconds before an API call
          #   times out, defaults to 60
          #
          # @option params :keep_alive[Boolean] Should the token for the connection
          #  for be automatically refreshed before it expires? Default is true
          #
          # @option params :pw_fallback [Boolean] If keep_alive, should the passwd be
          #   cached in memory and used to create a new token, if there are problems
          #   with the normal token refresh process?
          #
          # @option params :token [String] A valid token string. If provided, no need 
          #   to provide user:. pw: must only be provided if pw_fallback is set to true,
          #   and must be the correct pw for the user who generated the token string.
          #
          # @return [String] connection description, the output of #to_s
          #
          #######################################################
          def connect(url = nil, **params)
            raise ArgumentError, 'No url or connection parameters provided' if url.nil? && params.empty?

            # reset all values, flush caches
            disconnect

            # Get host, port, user and pw from a URL, or
            # build a base_url from those provided in the params
            # when finished, params will include
            # base_url, user, host, port, and possibly pw
            parse_url url, params

            # Default to prompting for the pw
            params[:pw] ||= :prompt

            prompt_for_password(params) if params[:pw] == :prompt

            # apply defaults from config, client, and then ruby-jss itself.
            apply_default_params params

            # Once we're here, all params have been parsed & defaulted into the
            # params hash, so make sure we have the minimum needed params for a connection
            verify_basic_params params

            # Now we can build out base url
            build_base_url params

            # it there's no @token yet, get one from a token string or a password
            create_token params

            # Now set our attribs

            @timeout = params[:timeout]
            @open_timeout = params[:open_timeout]
            
            @name ||= "#{user}@#{host}:#{port}"

            # the faraday connection object
            @cnx = create_connection

            @connect_time = Time.now
            @connected = true

            to_s
          end # connect
          alias login connect

          # raise exception if not connected, and make sure we're using
          # the current token
          def validate_connected
            using_dft = 'Xolo::Server::TitleEditor.cnx' if self == Xolo::Server::TitleEditor.cnx
            raise Xolo::NotConnectedError, "Connection '#{name}' Not Connected. Use #{using_dft}.connect first." unless connected?

            # update the Faraday connection to use the current token
            # if it has been auto-refreshed
            return if cnx.headers['Authorization'] == "Bearer #{@token.token}"

            cnx.authorization :Bearer, @token.token
          end

          # With a REST connection, there isn't any real "connection" to disconnect from
          # So to disconnect, we just unset all our credentials.
          #
          # @return [void]
          #
          #######################################################
          def disconnect
            @token&.disconnect
            @token = nil
            @cnx = nil          
        
            @connected = false
            :disconnected
          end # disconnect
          alias logout disconnect

          #####  Parsing Params & creating connections
          ######################################################
          private

          # Validate a token string, generating a fresh token and setting
          # @user. 
          # ######################################################ß˙
          def parse_token(params)
            return unless params[:token]

            @token = Xolo::Server::TitleEditor::Connection::Token.new(
              token_string: params[:token]
            )
          end

          # Get host, port, user and pw from a URL, or
          # build a base url from those provided in the params
          # when finished, params will include
          # base_url, user, host, port, and possibly pw
          #
          # @return [String, nil] the pw if present
          #
          #######################################################
          def parse_url(url, params)
            if url
              url = URI.parse url.to_s
              raise ArgumentError, 'Invalid url, scheme must be https' unless url.scheme == HTTPS_SCHEME

              params[:host] ||= url.host
              params[:port] ||= url.port unless url.port == SSL_PORT
              params[:user] ||= url.user if url.user
              params[:pw] ||= url.password if url.password
            end
          end

          # Apply defaults to the unset params for the #connect method
          # First apply them from from the Jamf.config,
          # then from the Jamf::Client (read from the jamf binary config),
          # then from the Jamf module defaults
          #
          # @param params[Hash] The params for #connect
          #
          # @return [Hash] The params with defaults applied
          #
          #######################################################
          def apply_default_params(params)
            apply_defaults_from_config(params)
            apply_module_defaults(params)
          end

          # Apply defaults from the Jamf.config
          # to the params for the #connect method
          #
          # @param params[Hash] The params for #connect
          #
          # @return [Hash] The params with defaults applied
          #
          #######################################################
          def apply_defaults_from_config(params)
            # settings from config if they aren't in the params
            params[:host] ||= Xolo.config.title_editor_server_name
            params[:port] ||= Xolo.config.title_editor_server_port
            params[:user] ||= Xolo.config.title_editor_username
            params[:timeout] ||= Xolo.config.title_editor_timeout
            params[:open_timeout] ||= Xolo.config.title_editor_open_timeout
            params[:ssl_version] ||= Xolo.config.title_editor_ssl_version

            # if verify cert was not in the params, get it from the prefs.
            # We can't use ||= because the desired value might be 'false'
            params[:verify_cert] = Xolo.config.title_editor_verify_cert if params[:verify_cert].nil?
          end # apply_defaults_from_config

          # Apply the module defaults to the params for the #connect method
          #
          # @param params[Hash] The params for #connect
          #
          # @return [Hash] The params with defaults applied
          #
          #######################################################
          def apply_module_defaults(params)
            # if we have no port set by this point, assume on-prem.
            params[:port] ||= SSL_PORT
            params[:timeout] ||= DFT_TIMEOUT
            params[:open_timeout] ||= DFT_OPEN_TIMEOUT
            params[:ssl_version] ||= DFT_SSL_VERSION
            # if we have a TTY, pw defaults to :prompt
            params[:pw] ||= :prompt if $stdin.tty?

            params[:keep_alive] = true unless params[:keep_alive] == false
            params[:pw_fallback] = true unless params[:pw_fallback] == false
            params[:verify_cert] = true unless params[:verify_cert] == false
          end

          # Raise execeptions if we don't have essential data for a new connection
          # namely a host, user, and pw
          #
          # @param params[Hash] The params for #connect
          #
          # @return [void]
          #
          #######################################################
          def verify_basic_params(params)
            # must have a host, it could have come from a url, or a param
            raise Xolo::MissingDataError, 'No :host specified in params or configuration.' unless params[:host]

            # no need for user or pass if using a token string
            # (tho a pw might be given)
            return if params[:token].is_a? String

            # must have user or token
            raise Xolo::MissingDataError, 'No :user or :token specified in params or configuration.' unless params[:user]
            # but here, theres no token so must have a pw
            raise Xolo::MissingDataError, "No :pw specified for user '#{params[:user]}'" unless params[:pw]
          end

          # create a token from a token string or a password
          #######################################################
          def create_token(params)          
            token_src = params[:token] ? :token_string : :pw
            @token = token_from token_src, params
          end

          # given a token string or a password, get a valid token
          # Token.new will raise an exception if the token string or
          # credentials are invalid
          #######################################################
          def token_from(type, params)
            token_params = {
              base_url: params[:base_url],
              user: params[:user],
              timeout: params[:timeout],
              keep_alive: params[:keep_alive],
              pw_fallback: params[:pw_fallback],
              ssl_version: params[:ssl_version],
              verify_cert: params[:verify_cert], 
              pw: params[:pw]
            }
            token_params[:token_string] = params[:token] if type == :token_string
    
            self.class::Token.new(**token_params)
          end

          # Build the base URL for the API connection
          #
          # @param args[Hash] The args for #connect
          #
          # @return [String] The URI encoded URL
          #
          #######################################################
          def build_base_url(params)
            params[:base_url] = +"#{HTTPS_SCHEME}://#{params[:host]}"
            params[:base_url] << ":#{params[:port]}" if params[:port] 
            params[:base_url] << "/#{RSRC_VERSION}"
          end

          # From whatever was given in args[:pw], figure out the real password
          #
          # @param args[Hash] The args for #connect
          #
          # @return [String] The password for the connection
          #
          #######################################################
          def prompt_for_password(params)
            return unless params[:pw] == :prompt

            user_display = 
              if params[:token]
                'the user who generated the given token'
              else
                "TitleEditor user #{params[:user]}@#{params[:host]}"
              end

            message = "Enter the password for #{user_display}:"
            begin
              $stdin.reopen '/dev/tty' unless $stdin.tty?
              $stderr.print "#{message} "
              system '/bin/stty -echo'
              pw = $stdin.gets.chomp("\n")
              puts
            ensure
              system '/bin/stty echo'
            end # begin
            
            params[:pw] = pw
          end

          # @return [Faraday::Connection]
          #######################################################
          def create_connection
            Faraday.new(@token.base_url, ssl: @token.ssl_options) do |cnx|
              cnx.authorization :Bearer, @token.token
    
              cnx.options[:timeout] = @timeout
              cnx.options[:open_timeout] = @open_timeout
     
              cnx.request :json
              cnx.response :json, parser_options: { symbolize_names: true }
    
              cnx.adapter :net_http
            end # Faraday.new
          end

        end # module

      end # class

    end # module

  end # module Server

end # module Jamf
