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

  module Server

    module Helpers

      # This is mixed in to Xolo::Server::App (as a helper, available in route processing)
      # and in Xolo::Server::Title and Xolo::Server::Version.
      #
      # This holds methods and constants for sending alerts and emails.
      #
      module Notification

        # Constants
        #####################
        #####################

        DFT_EMAIL_FROM = 'xolo-server-do-not-reply'

        # Module Methods
        #######################
        #######################

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # Instance Methods
        #######################
        ######################

        # Send a message thru the alert_tool, if one is defined in the config.
        #
        # Messages are prepended with "#{level} ALERT: "
        # This should be called by passing alert: true to one of the
        # logging wrapper methods
        #
        # @param msg [String] the message to send
        # @param level [Symbol] the log level of the message
        #
        # @return [void]
        ###############################
        def send_alert(msg, level)
          return unless Xolo::Server.config.alert_tool

          alerter = nil # just in case we need the ensure clause below.
          alerter = IO.popen(Xolo::Server.config.alert_tool, 'w')
          alerter.puts "#{level} ALERT: #{msg}"

        # this catches the quitting of the alerter before expected
        rescue Errno::EPIPE => e
          true
        ensure
          # this flushes the pipe and makes the msg go
          alerter&.close
        end

        # Send an email, if the smtp_server is defined in the config.
        #
        # @param to [String] the email address to send to
        # @param subject [String] the subject of the email
        # @param msg [String] the body of the email
        # @param html [Boolean] should the email be sent as HTML?
        #
        # @return [void]
        ###############################
        def send_email(to:, subject:, msg:, html: false)
          return unless Xolo::Server.config.smtp_server

          headers = [
            "From: #{server_name} <#{email_from}>",
            "Date: #{Time.now.rfc2822}",
            "To: #{to} <#{to}>",
            "Subject: #{subject}"
          ]

          if html
            headers << 'MIME-Version: 1.0'
            headers << 'Content-type: text/html'
          end

          msg = "#{headers.join "\n"}\n\n#{msg}"

          Net::SMTP.start(Xolo::Server.config.smtp_server) do |smtp|
            smtp.send_message msg, email_from, to
          end
        end

        # @return [String] the from address for emails
        ###############################
        def email_from
          @email_from ||= Xolo::Server.config.email_from || "#{DFT_EMAIL_FROM}@#{server_fqdn}"
        end

        # @return [String] the human-readable name of the server for sending emails
        ###############################
        def server_name
          @server_name ||= "Xolo Server on #{server_fqdn}"
        end

        # @return [String] the server's fully qualified domain name
        ###############################
        def server_fqdn
          @server_fqdn ||= Addrinfo.getaddrinfo(Socket.gethostname, nil).first.getnameinfo.first
        end

      end # Log

    end # Helpers

  end # Server

end # module Xolo
