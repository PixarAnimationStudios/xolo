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

require 'faraday' # >= 0.17.0
require 'faraday_middleware' # >= 0.13.0

module Xolo

  module Server 

    module TitleEditor

      # Instances of this class represent a connection to a Jamf Title Editor
      class Connection

        # the code for this class is broken into multiple files
        # as modules, to play will with the zeitwerk loader
        include Xolo::Server::TitleEditor::Connection::Constants
        include Xolo::Server::TitleEditor::Connection::Attributes
        include Xolo::Server::TitleEditor::Connection::Connect
        include Xolo::Server::TitleEditor::Connection::Actions

        # Constructor
        #####################################

        # Instantiate a connection object.
        #
        # If name: is provided it will be stored as the Connection's name attribute.
        #
        # if no url is provided and params are empty, or contains only
        # a :name key, then you must call #connect with all the connection
        # parameters before accessing a server.
        #
        # See {#connect} for the parameters
        #
        def initialize(url = nil, **params)
          @name = params.delete :name
          @connected = false

          return if url.nil? && params.empty?

          connect url, **params
        end # init

        # Instance methods
        #####################################

        # A useful string about this connection
        #
        # @return [String]
        #
        def to_s
          return 'not connected' unless connected?

          if name.to_s.start_with? "#{user}@"
            name
          else
            "#{user}@#{host}:#{port}, name: #{name}"
          end
        end

        # Only selected items are displayed with prettyprint
        # otherwise its too much data in irb.
        #
        # @return [Array] the desired instance_variables
        #
        def pretty_print_instance_variables
          PP_VARS
        end

        # @deprecated, use .token.next_refresh
        def next_refresh
          @token.next_refresh
        end

        # @deprecated, use .token.secs_to_refresh
        def secs_to_refresh
          @token.secs_to_refresh
        end

        # @deprecated, use .token.time_to_refresh
        def time_to_refresh
          @token.time_to_refresh
        end

        # is this the default connection?
        def default?
          self == Xolo::Server::TitleEditor.cnx
        end

      end # class Connection

    end # module TitleEditor

  end # module Server

end # module
