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
#

require 'rest-client'

# the main module
module D3

  # a connection to the d3 server
  class Connection

    SESSION_RSRC = 'session'.freeze
    SESSION_VALID_RSRC = "#{SESSION_RSRC}/valid".freeze

    # @return [RestClient::Resource] our underlying server connection
    attr_reader :restcnx

    def initialize(user = nil, pw = nil)
      # TODO: build this from config using server & port
      @base_url = 'https://d3server.pixar.com/api/v1/'

      # TODO: build this from config using verify_ssl:, timeout:, open_timeout:
      @cnx_opts = {
        use_ssl: true,
        content_type: :json,
        accept: :json
      }
      @restcnx = RestClient::Resource.new @base_url, @cnx_opts
      @connected = false
      connect(user, pw) if user && pw
    end

    def connect(user, pw)
      session = initiate_session(user, pw)
      @user = user
      @cnx_opts[:cookies] = { D3::SESSION_KEY => session }
      @restcnx = RestClient::Resource.new @base_url, @cnx_opts
      @connected = true
    end
    alias login connect

    # @return [String] the new session token
    #
    def initiate_session(user, pw)
      login_rsrc = "#{@base_url}/#{SESSION_RSRC}"
      login_opts = @cnx_opts.merge(user: user, password: pw)
      login_cnx = RestClient::Resource.new(login_rsrc, login_opts)
      login_resp = login_cnx.post nil
      login_resp.cookies[D3::SESSION_KEY]
    end
    private :initiate_session

    def connected?
      @connected
    end

    def disconnect
      delete SESSION_RSRC if session_valid?
      @user = nil
      @cnx_opts.delete :cookies
      @restcnx = RestClient::Resource.new @base_url, @cnx_opts
      @connected = false
    end
    alias logout disconnect

    # TODO: needed?
    def session_valid?
      parse_response(@restcnx[SESSION_VALID_RSRC].get)[:status] == D3::Server::API_OK_STATUS
    end

    def get(rsrc)
      validate_connection
      parse_response @restcnx[rsrc].get
    rescue RestClient::Exception => e
      handle_http_error e
    end

    def post(rsrc, json_data)
      validate_connection
      parse_response @restcnx[rsrc].post json_data
    rescue RestClient::Exception => e
      handle_http_error e
    end

    def put(rsrc, json_data)
      validate_connection
      parse_response @restcnx[rsrc].put json_data
    rescue RestClient::Exception => e
      handle_http_error e
    end

    def delete(rsrc)
      validate_connection
      parse_response @restcnx[rsrc].delete
    rescue RestClient::Exception => e
      handle_http_error e
    end

    def validate_connection
      raise D3::ConnectionError, 'Not connected' unless connected?
    end
    private :validate_connection

    def parse_response(resp)
      @last_http_response = resp
      JSON.d3parse resp.body
    rescue JSON::ParserError
      { status: 'error', message: "Invalid JSON: '#{resp.body}'" }
    end
    private :parse_response

    # Extract the error message from the
    # response json, or the whole response body
    # and re-raise with the custom error message
    def handle_http_error(exception)
      @last_http_response = exception.response
      exception.message =
        begin
          JSON.d3parse(@last_http_response.body)[:message]
        rescue JSON::ParserError
          @last_http_response.body
        end
      raise exception
    end
    private :handle_http_error

  end # class Connection

  def self.cnx
    @connection ||= D3::Connection.new
  end

  def self.cnx=(connx)
    @connection = connx
  end

  # TODO: put these in another file

  # @return [Hash{String => Integer}] names => ids for JSS computer groups
  def self.computer_groups
    hash = {}
    cnx.get('computer_groups')[:computer_groups].each { |g| hash[g[:name]] = g[:id] }
    hash
  end

  # @return [Hash{String => Integer}] names => ids for JSS packages
  def self.packages
    hash = {}
    D3.cnx.get('packages')[:packages].each { |g| hash[g[:name]] = g[:id] }
    hash
  end

  # @return [Hash{String => Integer}] names => ids for JSS scripts
  def self.scripts
    hash = {}
    D3.cnx.get('scripts')[:scripts].each { |g| hash[g[:name]] = g[:id] }
    hash
  end

  # @return [Hash{String => Integer}] names => ids for JSS categories
  def self.categories
    hash = {}
    D3.cnx.get('categories')[:categories].each { |g| hash[g[:name]] = g[:id] }
    hash
  end

  # @return [Hash{String => Integer}] names => ids for JSS policies
  def self.policies
    hash = {}
    D3.cnx.get('policies')[:policies].each { |g| hash[g[:name]] = g[:id] }
    hash
  end

  # @return [Array<String>] the names of all d3/patch extension attribs
  def self.d3_extension_attribs
    @current_d3_extension_attribs ||= D3.cnx.get('ext_attrs')
  end

  # @return [Array<String>] the names of all regular Computer extension attribs
  def self.computer_extension_attribs
    @current_computer_extension_attribs ||= D3.cnx.get('ext_attrs/nonpatch')
  end

end # module D3
