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
# 

# frozen_string_literal: true

module Xolo

  module Server 

    module TitleEditor

      # Module methods and aliases for dealing with the default connection
      # This is extended into the TitleEditor module itself
      ######################
      module DefaultConnection

        def self.extended(extender)
          Xolo.verbose_extend extender, self 
        end

        # The current default Jamf::Connection instance.
        #
        # @return [Jamf::Connection]
        #
        def cnx
          @default_connection ||= Xolo::Server::TitleEditor::Connection.new name: :default
        end

        # Create a new Connection object and use it as the default for all
        # future API calls. This will replace the existing default connection with
        # a totally new one
        #
        # @param (See Jamf::Connection#initialize)
        #
        # @return [String] the to_s output of the new connection
        #
        def connect(url = nil, **params)
          params[:name] ||= :default
          @default_connection = Xolo::Server::TitleEditor::Connection.new url, **params
          @default_connection.to_s
        end
        alias login connect

        # Use the given Jamf::Connection object as the default connection, replacing
        # the one that currently exists.
        #
        # @param connection [Jamf::Connection] The default Connection to use for future
        #   API calls
        #
        # @return [APIConnection] The connection now being used.
        #
        def cnx=(connection)
          unless connection.is_a? Xolo::Server::TitleEditor::Connection
            raise 'TitleEditor connections must be instances of Xolo::Server::TitleEditor::Connection'
          end

          @default_connection = connection
        end

        # Disconnect the default connection
        #
        def disconnect
          @default_connection.disconnect if @default_connection&.connected?
        end
        alias logout disconnect

      end # module DefaultConnection

    end # module Title Editor

  end # module Server

end # module xolo
