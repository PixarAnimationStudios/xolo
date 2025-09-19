# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#
#

# frozen_string_literal: true

# main module
module Xolo

  module Admin

    # Faraday Middleware for storing and sending the only cookie we
    # use with the Xolo server.
    #
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

      # we only send back the rack.session cookie, as long as it
      # exists and hasn't expired (it lasts an hour)
      #####################
      def on_request(env)
        return unless self.class.session_cookie && self.class.session_expires

        raise Xolo::InvalidTokenError, 'Server Session Expired' if Time.now > self.class.session_expires

        env[:request_headers][COOKIE_HEADER] = "#{SESSION_COOKIE_NAME}=#{self.class.session_cookie}"
      end

      # The server only ever sends one cookie,
      # and we only care about 2 values:
      # rack.session, and expires
      ####################
      def on_complete(env)
        raw_cookie = env[:response_headers][SET_COOKIE_HEADER]
        return unless raw_cookie

        tepid_cookie = raw_cookie.split(Xolo::SEMICOLON_SEP_RE)
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
