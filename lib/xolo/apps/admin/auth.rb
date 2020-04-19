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

module Xolo

  # The d3admin app
  class AdminApp

    # methods for storing & retrieving credentials in the user's
    # keychain, and using the to connect to the JSS and d3 server
    # (d3 server uses same credentials as the JSS)
    #
    # User must be in the Jamf admin group defined on the server.
    #
    # JSS api settings (servername, port, SSL settings, etc)
    # must be set in /etc/ruby-jss.conf

    KEYCHAIN_JSS_SERVICE = 'd3admin.jss-api'.freeze
    KEYCHAIN_JSS_LABEL = 'com.pixar.d3.admin.jss-api'.freeze

    # @return [String] the connected admin name
    #
    def connect
      admin, pw = admin_credentials
      D3.cnx.connect admin, pw
      JSS.api.connect user: admin, pw: pw, open_timeout: 10
      @connected = true
      admin
    end

    def disconnect
      D3.cnx.disconnect
      JSS.api.disconnect
      @connected = false
      @admin = nil
    end

    def connected?
      @connected
    end

    # Fetch read-write credentials from the login keychain or the user
    #
    # If the login keychain is locked, the user will be prompted
    # to unlock it in the GUI.
    #
    # If no credentials are saved, user is prompted for them
    #
    # @return [Array<String>] An Array with [user, password]
    #
    def admin_credentials
      Keychain.user_interaction_allowed = true
      unlock_keychain
      search_conditions = { service: KEYCHAIN_JSS_SERVICE, label: KEYCHAIN_JSS_LABEL }

      pw_item = Keychain.default.generic_passwords.where(search_conditions).first

      return [pw_item.account, pw_item.password] if pw_item
      prompt_for_admin_credentials
    end

    # Prompt for admin credentials, store them in the default
    # (login) keychain, and return in an array
    #
    # Raises an exception after 3 failures
    #
    # @return [Array<String>] An Array with [user, password]
    #
    def prompt_for_admin_credentials
      jamf_server = JSS::CONFIG.api_server_name
      print "Enter your Jamf username for #{jamf_server}"
      user = $stdin.gets.chomp
      prompt = "Password for #{user}@#{jamf_server}: "
      pw =
        try_pw_three_times(prompt, user) do |u, p|
          begin
            JSS.api.connect user: u, pw: p
            true
          rescue JSS::AuthenticationError
            false
          end
        end

      # did we get it in 3 tries?
      raise JSS::AuthenticationError, 'Three wrong attempts, please contact a Jamf Pro administrator if you need access.' unless pw

      save_credentials(user, pw)
      puts "\nThanks, your credentials have been saved in your keychain"

      # we should now have valid user and pw
      [user, pw]
    end # prompt_for_admin_credentials


    # Save a user and password to the login keychain
    #
    # Note: assumes the validity of the credentials
    #
    # @param user[String] the username to check
    #
    # @param pw[String] the password to try with the username
    #
    # @return [Boolean] were the user and  password valid?
    #
    def save_credentials(user, pw)
      pw_item = Keychain.default.generic_passwords.where(service: KEYCHAIN_JSS_SERVICE, label: KEYCHAIN_JSS_LABEL, account: user).first
      pw_item.delete  if pw_item
      Keychain.default.generic_passwords.create service: KEYCHAIN_JSS_SERVICE, label: KEYCHAIN_JSS_LABEL, account: user, password: pw
    end

    # Prompt the user to unlock the default keychain if its locked
    # Raise error if unlock fails
    #
    # @return [void]
    #
    def unlock_keychain
      return true unless Keychain.default.locked?
      puts 'Please enter the password for your login keychain'
      pw =
        try_pw_three_times('Keychain password: ') do |_u, p|
          begin
            Keychain.default.unlock! p
            true
          rescue Keychain::AuthFailedError
            false
          end
        end
      raise Keychain::AuthFailedError, 'Three incorrect attempts to unlock keychain' unless pw
      true
    end # unlock keychain

    # Provide a prompt, an optional user name, and a block
    # that takes one param, the pw typed by the user. The block
    # tries to validate the passwd and returns a boolean indicating
    # success
    #
    # @param prompt [Type] describe_prompt_here
    # @yield [user, pw] The user & typed passwd is given to the block, which
    #   does the validation and returns a boolean. user may be nil
    # @yieldreturn [Boolean] Was the password valid?
    # @return [String, nil] The valid passwd or nil
    #
    def try_pw_three_times(prompt, user = nil, &block)
      tries = 0
      pw = nil
      until tries == 3
        print prompt
        system 'stty -echo'
        pw = $stdin.gets.chomp
        system 'stty echo'
        break if yield user, pw
        puts "\nSorry, that was incorrect"
        tries += 1
      end # while
      # did we get it in 3 tries?
      tries == 3 ? nil : pw
    ensure
      # make sure terminal is usable at the end of this
      system 'stty echo'
    end
    private :try_pw_three_times

  end # class Admin app

end # module Xolo
