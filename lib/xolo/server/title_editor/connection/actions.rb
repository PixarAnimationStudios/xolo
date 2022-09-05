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

      class Connection

        # This module defines methods used for interacting with the TitleEditor API.
        # This includes sending HTTP requests and handling responses
        module Actions

          def self.included(includer)
            Xolo.verbose_include(includer, self)
          end
          
          # @param rsrc[String] the resource path to get
          #
          # @return [Object] The parsed JSON from the result of the request
          #
          def get(rsrc)
            validate_connected

            resp = cnx.get(rsrc)
            @last_http_response = resp
            return resp.body if resp.success?

            handle_http_error resp
          end # get

          # Create a new API resource via POST
          #
          # @param rsrc[String] the API resource being created, the URL part after 'JSSResource/'
          #
          # @param content[String] the content specifying the new object.
          #
          # @return [Object] The parsed JSON from the result of the request
          #
          def post(rsrc, content)
            validate_connected

            # send the data
            resp = cnx.post(rsrc) { |req| req.body = content }
            @last_http_response = resp
            return resp.body if resp.success?

            handle_http_error resp
          end # post

          # Update an existing API resource via PUT
          #
          # @param rsrc[String] the API resource being changed, the URL part after 'JSSResource/'
          #
          # @param content[String] the content specifying the changes.
          #
          # @return [Object] The parsed JSON from the result of the request
          #
          def put(rsrc, content)
            validate_connected

            # send the data
            resp = cnx.put(rsrc) { |req| req.body = content }
            @last_http_response = resp
            return resp.body if resp.success?

            handle_http_error resp
          end # put

          # Delete a resource from the API
          #
          # @param rsrc[String] the resource to delete
          #
          # @return [Object] The parsed JSON from the result of the request
          #
          def delete(rsrc)
            validate_connected

            # send the data
            resp = cnx.delete(rsrc)
            @last_http_response = resp
            return resp.body if resp.success?

            handle_http_error resp
          end # delete_rsrc

          #############################
          private

          # Parses the given http response
          # and raises a Jamf::APIError with a useful error message.
          #
          # @return [void]
          #
          def handle_http_error(resp)
            return if resp.success?

            case resp.status
            when 404
              err = Xolo::NoSuchItemError
              msg = 'Not Found'

            when 401
              err = Xolo::PermissionError
              msg = 'You are not authorized to do that.'

            when (500..599)
              err = Xolo::ConnectionError
              msg = 'There was an internal server error'

            else
              err = Xolo::ConnectionError
              msg = "There was a error processing your request, status: #{resp.status}"
              
            end # case
            mag = "#{msg}\nResponse Body:\n#{resp.body}"
            raise err, msg
          end

        end # module Actions

      end # class Connection

    end # module TitleEditor

  end # module Server

end # module
