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

    # Faraday Middleware for storing and sending the only cookie we
    # use with the Xolo server.
    # See https://lostisland.github.io/faraday/#/middleware/custom-middleware
    #
    class CookieJar < Faraday::Middleware

      # Constants
      ##########################
      ##########################

      COOKIE_HEADER = 'Cookie'
      SET_COOKIE_HEADER = 'set-cookie'
      SESSION_COOKIE_NAME = 'rack.session'
      SESSION_COOKIE_EXPIRES_NAME = 'expires'

      # Class Methods
      ##########################
      ##########################

      class << self

        # runtime storage for our single cookie
        attr_accessor :session_cookie, :session_expires

      end

      # Instance Methods
      ##########################
      ##########################

      # we only send back the rack.session cookie, as long as it hasn't expired
      #####################
      def on_request(env)
        # do something with the request
        # env[:request_headers].merge!(...)
        return unless self.class.session_cookie && self.class.session_expires

        raise Xolo::InvalidTokenError, 'Server Session Expired' if Time.now > self.class.session_expires

        env[:request_headers][COOKIE_HEADER] = "#{SESSION_COOKIE_NAME}=#{self.class.session_cookie}"
      end

      # The server only ever sends one cookie, and we only care about 2 values,
      # the rack.session, and expires
      ####################
      def on_complete(env)
        # do something with the response
        # env[:response_headers].merge!(...)
        raw_cookie = env[:response_headers][SET_COOKIE_HEADER]
        return unless raw_cookie

        tepid_cookie = raw_cookie.split(/\s*;\s*/)
        tepid_cookie.each do |part|
          name, value = part.split('=')
          case name
          when SESSION_COOKIE_NAME
            self.class.session_cookie = value
          when SESSION_COOKIE_EXPIRES_NAME
            self.class.session_expires = Time.parse(value).localtime
          end
        end
      end

    end # module Converters

  end # module Admin

end # module Xolo
