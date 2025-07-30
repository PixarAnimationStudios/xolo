# Copyright 2025 Pixar
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

    # Personal credentials for users of 'xadm', stored in the login keychain
    #
    module Credentials

      # Constants
      ##############################
      ##############################

      # The security command
      SEC_COMMAND = '/usr/bin/security'

      # exit status when the login keychain can't be accessed because we aren't in a GUI session
      SEC_STATUS_NO_GUI_ERROR = 36

      # exit status when the keychain password provided is incorrect
      SEC_STATUS_AUTH_ERROR = 51

      # exit status when the desired item isn't found in the keychain
      SEC_STATUS_NOT_FOUND_ERROR = 44

      # The 'kind' of item in the keychain
      XOLO_CREDS_KIND = 'Xolo::Admin::Password'

      # the Service for the generic 'Xolo::Admin::Credentials' keychain entry
      XOLO_CREDS_SVC = 'com.pixar.xolo.password'

      # the Label for the generic 'Xolo::Admin::Credentials' keychain entry
      XOLO_CREDS_LBL = '"Xolo Admin Password"'

      # Module methods
      ##############################
      ##############################

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # Instance Methods
      ##########################
      ##########################

      # If the keychain is not accessible, prompt for the password
      #
      # @return [String] Get the admin's password from the login keychain
      #
      ##############################################
      def fetch_pw
        cmd = ['find-generic-password']
        cmd << '-s'
        cmd << XOLO_CREDS_SVC
        cmd << '-l'
        cmd << XOLO_CREDS_LBL
        cmd << '-w'
        run_security(cmd.map { |i| security_escape i }.join(' '))

      # If we can't access the keychain, prompt for the password. This is usually
      # when we're running in a non-GUI session, e.g. via ssh.
      rescue Xolo::KeychainError
        raise unless @security_exit_status.exitstatus == SEC_STATUS_NO_GUI_ERROR

        question = "Keychain not accessible.\nPlease enter the xolo admin password for #{config.admin}: "
        highline_cli.ask(question) do |q|
          q.echo = false
        end
      end

      # Store an item in the default keychain
      #
      # @param acct [String] The username for the password.
      #   xadm doesn't use this, it uses the admin name from the
      #   configuration. But the keychain item requires a value here.
      #
      # @param pw [String] The password to store
      #
      # @return [void]
      ##############################################
      def store_pw(acct, pw)
        # delete the item first if its there
        delete_pw

        cmd = ['add-generic-password']
        cmd <<  '-a'
        cmd <<  acct
        cmd << '-s'
        cmd << XOLO_CREDS_SVC
        cmd << '-w'
        cmd << pw
        cmd << '-l'
        cmd << XOLO_CREDS_LBL
        cmd << '-D'
        cmd << XOLO_CREDS_KIND

        run_security(cmd.map { |i| security_escape i }.join(' '))
      end

      # delete the xolo admin password from the login keychain
      # @return [void]
      ##############################################
      def delete_pw
        cmd = ['delete-generic-password']
        cmd << '-s'
        cmd << XOLO_CREDS_SVC
        cmd << '-l'
        cmd << XOLO_CREDS_LBL

        run_security(cmd.map { |i| security_escape i }.join(' '))
      rescue Xolo::NoSuchItemError
        nil
      rescue RuntimeError => e
        raise e unless e.to_s == 'No matching keychain item was found'

        nil
      end

      # Run the security command in interactive mode on a given keychain,
      # passing in a subcommand and its arguments. so that they don't appear in the
      # `ps` output
      #
      # @param cmd [String] the subcommand being passed to 'security' with
      #   all needed options. It will not be visible outide this process, so
      #   its OK to put passwords into the options.
      #
      # @return [String] the stdout of the 'security' command.
      #
      ######
      def run_security(cmd)
        output = Xolo::BLANK
        errs = Xolo::BLANK

        Open3.popen3("#{SEC_COMMAND} -i") do |stdin, stdout, stderr, wait_thr|
          # pid = wait_thr.pid # pid of the started process.
          stdin.puts cmd
          stdin.close

          output = stdout.read
          errs = stderr.read

          @security_exit_status = wait_thr.value # Process::Status object returned.
        end
        # exit 44 is 'The specified item could not be found in the keychain'
        return output.chomp if @security_exit_status.success?

        case @security_exit_status.exitstatus
        when SEC_STATUS_AUTH_ERROR
          raise Xolo::KeychainError, 'Problem accessing login keychain. Is it locked?'

        when SEC_STATUS_NOT_FOUND_ERROR
          raise Xolo::NoSuchItemError, "No xolo admin password. Please run 'xadm config'"

        else
          errs.chomp!
          errs =~ /: returned\s+(-?\d+)$/
          errnum = Regexp.last_match(1)
          desc = errnum ? security_error_desc(errnum) : errs
          desc ||= errs
          raise Xolo::KeychainError, "#{desc.gsub("\n", '; ')}; exit status #{@security_exit_status.exitstatus}"
        end # case
      end # run_security

      # use `security error` to get a description of an error number
      ##############
      def security_error_desc(num)
        desc = `#{SEC_COMMAND} error #{num}`
        return if desc.include?('unknown error')

        desc.chomp.split(num).last
      rescue StandardError
        nil
      end

      # given a string, wrap it in single quotes and escape internal single quotes
      # and backslashes so it can be used in the interactive 'security' command
      #
      # @param str[String] the string to escape
      #
      # @return [String] the escaped string
      ###################
      def security_escape(str)
        # first escape backslashes
        str = str.to_s.gsub '\\', '\\\\\\'

        # then single quotes
        str.gsub! "'", "\\\\'"

        # if other things need escaping, add them here

        "'#{str}'"
      end # security_escape

    end # module Prefs

  end # module Admin

end # module Xolo
