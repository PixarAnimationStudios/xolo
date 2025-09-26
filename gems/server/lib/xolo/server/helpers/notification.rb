# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
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

        ALERT_TOOL_EMAIL_PREFIX = 'email:'

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
          return if send_email_alert(msg, level)

          alerter = nil # just in case we need the ensure clause below.
          alerter = IO.popen(Xolo::Server.config.alert_tool, 'w')
          alerter.puts "#{level} ALERT: #{msg}"

        # this catches the quitting of the alerter before expected
        rescue Errno::EPIPE
          true
        ensure
          # this flushes the pipe and makes the msg go
          alerter&.close
        end

        # Send an alert via email
        # @param msg [String] the message to send
        # @param level [Symbol] the log level of the message
        #
        # @return [Boolean] true if the email was sent, false otherwise
        ################################
        def send_email_alert(msg, level)
          return false unless Xolo::Server.config.smtp_server
          return false unless Xolo::Server.config.alert_tool.start_with? ALERT_TOOL_EMAIL_PREFIX

          send_email(
            to: Xolo::Server.config.alert_tool.delete_prefix(ALERT_TOOL_EMAIL_PREFIX).strip,
            subject: "#{level} ALERT from Xolo Server",
            msg: msg
          )
          true
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
