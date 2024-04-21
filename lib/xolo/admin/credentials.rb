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

    # Personal credentials for users of 'xadm', stored in the login keychain
    module Credentials

      # Constants
      ##############################
      ##############################

      # The security command
      SEC_COMMAND = '/usr/bin/security'

      # exit status when the keychain password provided is incorrect
      SEC_STATUS_AUTH_ERROR = 51

      # exit status when the desired item isn't found in the keychain
      SEC_STATUS_NOT_FOUND_ERROR = 44

      # The 'kind' of item in the keychain
      XOLO_CREDS_KIND = 'Xolo::Admin::Credentials'

      # the Service for the generic 'Xolo::Admin::Credentials' keychain entry
      XOLO_CREDS_SVC = 'com.pixar.xolo.credentials'

      # the Label for the generic 'Xolo::Admin::Credentialss' keychain entry
      XOLO_CREDS_LBL = '"Xolo Admin Login and Password"'

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

      # Get an account and password from the login keychain
      #
      # Search terms are attributes of a 'generic password' and must be
      # one or more of:
      #
      #    account:, service:, label:, creator:, type:, generic:, or comment:
      #
      #    value: can be used as a synonym for generic:
      #
      # NOTE: 'kind:' is always set to ITEM_KIND for items created by this module
      #
      # The combination of account and service are guaranteed to be unique in the
      # keychain.
      #
      # For items created by this module, service and label also make a unique
      # item.
      #
      # WARNING: if your search matches more than one item, only the first is
      # returned.
      #
      # See also the initialize methods of MacKeychain::GenericPassword and
      # MacKeychain::Password for info about the search terms
      #
      # @return [Array <String>] A 2-item array containing [account, pw] for the
      #   item, or an empty array if not found in the keychain
      #
      ##############################################
      def credentials
        cmd = ['find-generic-password']
        cmd << '-s'
        cmd << XOLO_CREDS_SVC
        cmd << '-l'
        cmd << XOLO_CREDS_LBL

        run_security(cmd.map { |i| security_escape i }.join(' ')) =~ /"acct"<blob>="(.*)"/
        user = Regexp.last_match(1)

        cmd << '-w'
        pw = run_security(cmd.map { |i| security_escape i }.join(' '))

        { user: user, pw: pw }
      end

      # prompt for an account and passwd to store in the keychain
      #
      # Requires a block taking takes 2 params, user and pw, and returning
      # true if they work and false if not.
      #
      # @return [Array<String>] The valid [account, password]
      #
      ##############################################
      def prompt_to_store_credentials
        validate_not_root
        username_prompt = "#{username_prompt.chomp} "

        puts message
        account = nil
        pw = nil
        until account && pw
          print username_prompt
          account = $stdin.gets.chomp
          print 'password: '
          system 'stty -echo'
          pw = $stdin.gets.chomp
          system 'stty echo'

          success = yield(account, pw)

          if success
            puts
            store_credentials(account: account, pw: pw, service: service, label: label, **attributes)
            return [account, pw]
          end

          puts "\nIncorrect username or password"
          account = nil
          pw = nil
        end # until
      ensure
        system 'stty echo'
      end # prompt_to_store_creds

      # Store an item in the default keychain
      ##############################################
      def store_credentials(user:, pw:)
        # delete the item first if its there
        delete_credentials

        cmd = ['add-generic-password']
        cmd <<  '-a'
        cmd <<  user
        cmd << '-s'
        cmd << XOLO_CREDS_SVC
        cmd <<  '-w'
        cmd <<  pw
        cmd <<  '-l'
        cmd <<  XOLO_CREDS_LBL
        cmd <<  '-D'
        cmd <<  XOLO_CREDS_KIND

        run_security(cmd.map { |i| security_escape i }.join(' '))
      end

      # delete the xolo admin creds from the login keychain
      ##############################################
      def delete_credentials
        cmd = ['delete-generic-password']
        cmd << '-s'
        cmd << XOLO_CREDS_SVC
        cmd <<  '-l'
        cmd <<  XOLO_CREDS_LBL

        run_security(cmd.map { |i| security_escape i }.join(' '))
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
        output = ''
        errs = ''
        exit_status = nil

        Open3.popen3("#{SEC_COMMAND} -i") do |stdin, stdout, stderr, wait_thr|
          # pid = wait_thr.pid # pid of the started process.
          stdin.puts cmd
          stdin.close

          output = stdout.read
          errs = stderr.read

          exit_status = wait_thr.value # Process::Status object returned.
        end
        # exit 44 is 'The specified item could not be found in the keychain'
        return output.chomp if exit_status.success?

        case exit_status.exitstatus
        when SEC_STATUS_AUTH_ERROR
          raise 'Incorrect user or password'

        when SEC_STATUS_NOT_FOUND_ERROR
          raise 'No matching keychain item was found'

        else
          errs.chomp!
          errs =~ /: returned\s+(-?\d+)$/
          errnum = Regexp.last_match(1)
          desc = errnum ? security_error_desc(errnum) : errs
          desc ||= errs
          raise "#{desc.gsub("\n", '; ')}; exit status #{exit_status.exitstatus}"
        end # case
      end # run_security

      # use `security error` to get a description of an error number
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
      #
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
