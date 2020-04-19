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


#
module Xolo

  module Admin
    module Prefs

      ############### Admin User Prefs #################

      ############### Module Constants #################

      PREFS_DIR = Pathname.new(ENV['HOME'].to_s).expand_path + "Library/Preferences"
      PREFS_FILE = PREFS_DIR + "com.pixar.d3.admin.yaml"

      PREF_KEYS = {
        :workspace => {
          description: "Path to the directory where new pkg and dmg packages are built.\n If unset, defaults to your home folder"
        },

        :editor =>{
          description: "Preferred shell command for editing package descriptions in --walkthru"
        },

        :apple_pkg_id_prefix => {
          description: "The Apple package id prefix, e.g. 'com.mycompany'.\nWhen .pkgs are built, the identifier will be this, plus the title.\n If unset, the default is '#{Xolo::Admin::DFT_PKG_ID_PREFIX}'"
        },

        :last_config => {
          description: "Timestamp of the last configuration for setting servers, credentials and/or prefs"
        }
      }

      @@prefs = PREFS_FILE.readable? ? YAML.load(PREFS_FILE.read) : {}

      # Return a hash of prefs for this admin
      #
      # @return [Hash] the d3admin prefs for the current user
      #
      def self.prefs
        @@prefs
      end

      # Set a pref and save the change
      #
      # @param pref[Symbol] the pref to set, one of the keys of PREF_KEYS
      #
      # @param value[Object] the value to save with the pref
      #
      # @return [Boolean] true of the pref was set and saved
      def self.set_pref (pref, value)
        raise JSS::InvalidDataError, "first argument must be a pref key from Xolo::Admin::Prefs::PREF_KEYS" unless PREF_KEYS.keys.include? pref
        @@prefs[pref] = value
        save_prefs
      end

      # Save the current prefs to disk for this user
      #
      # @return [void]
      def self.save_prefs
        @@prefs[:last_config] =  Time.now
        PREFS_FILE.jss_save YAML.dump(@@prefs)
      end


      # Run the Admin config, saving hostnames, usernames and pws
      # as needed.
      #
      # @param targets[Array] the targets from the d3admin command-line
      #
      # @param options[OpenStruct] the parsed options from the
      #   d3admin command-line
      #
      # @return [void]
      #
      # @todo  improve this a lot
      #
      def self.config (targets, options)

        if options.walkthru
          tgt = Xolo::Admin::Interactive.get_value :get_config_target, "all"
          targets = [tgt]
        end

        if targets.empty? or targets.include?("all")
          targets = Xolo::Admin::CONFIG_TARGETS - ["all"]
        end

        targets.each do |target|
          case target
          when"jss"
            puts "********  JSS-API LOCATION AND READ-WRITE CREDENTIALS  ********"
            Xolo::Admin::Auth.ask_for_rw_credentials :jss

          when "db"
            puts "********  JSS MYSQL LOCATION AND READ-WRITE CREDENTIALS  ********"
            Xolo::Admin::Auth.ask_for_rw_credentials :db

          when "dist"
            puts "********  MASTER DIST-POINT READ-WRITE PASSWORD  ********"
           Xolo::Admin::Auth.ask_for_rw_credentials :dist

          when "workspace"
            puts "********  LOCAL PKG/DMG BUILD WORKSPACE  ********"
            pth = Xolo::Admin::Interactive.get_value :workspace, Xolo::Admin::Prefs.prefs[:workspace]
            Xolo::Admin::Prefs.set_pref :workspace, pth
            Xolo::Admin::Prefs.save_prefs
            puts "Thank you, the path has been saved in your d3admin prefs"
            puts

          when "editor"
            puts "********  TEXT EDITOR  ********"
            cmd = Xolo::Admin::Interactive.get_value :get_editor, Xolo::Admin::Prefs.prefs[:editor]
            Xolo::Admin::Prefs.set_pref :editor, cmd
            Xolo::Admin::Prefs.save_prefs
            puts "Thank you, the command has been saved in your d3admin prefs"
            puts

          when "pkg-id-prefix"
            puts "********  .PKG IDENTIFIER PREFIX  ********"
            pfx = Xolo::Admin::Interactive.get_value(:get_pkg_identifier_prefix, Xolo::Admin::Prefs.prefs[:apple_pkg_id_prefix], :validate_package_identifier_prefix)
            Xolo::Admin::Prefs.set_pref :apple_pkg_id_prefix, pfx
            Xolo::Admin::Prefs.save_prefs
            puts "Thank you, the prefix has been saved in your d3admin prefs"
            puts
          else
            puts "(skipping unknown config setting: #{target}"
          end # case
        end # targets.each
      end # config

      # Display the current Admin config settings
      #
      # @return [void]
      #
      def self.display_config
        jss_creds = Xolo::Admin::Auth.rw_credentials :jss, :just_checking
        jss_server = JSS::CONFIG.api_server_name # should be the one saved in the user-level .ruby-jss.conf, not top level in /etc
        jss_port = JSS::CONFIG.api_server_port

        db_creds = Xolo::Admin::Auth.rw_credentials :db, :just_checking
        db_server = JSS::CONFIG.db_server_name
        db_port = JSS::CONFIG.db_server_port

        dist_creds = Xolo::Admin::Auth.rw_credentials :dist, :just_checking

        wkspc = Xolo::Admin::Prefs.prefs[:workspace]
        pkg_id_pfx = Xolo::Admin::Prefs.prefs[:apple_pkg_id_prefix]
        editor = Xolo::Admin::Prefs.prefs[:editor]

        puts <<-DISPLAY
********  Current d3admin config  ********
JSS API
  Hostname: #{jss_server}
  Port: #{jss_port}
  Read/Write user: #{jss_creds[:user] ? jss_creds[:user] : 'unset' }
  Read/Write password: #{jss_creds[:password] ? 'stored in keychain' : 'unset' }

JSS MySQL
  Hostname: #{db_server}
  Port: #{db_port}
  Read/Write user: #{db_creds[:user] ? db_creds[:user] : 'unset' }
  Read/Write password: #{db_creds[:password] ? 'stored in keychain' : 'unset' }

Master Distribution Point
  Hostname: (stored in JSS)
  Port: (stored in JSS)
  Read/Write user: (stored in JSS)
  Read/Write password: #{dist_creds[:password] ? 'stored in keychain' : 'unset' }

Adding Packages
  Description Editor: #{editor ? editor : Xolo::Admin::Interactive::DFT_EDITOR}
  Build Workspace: #{wkspc ? wkspc : Xolo::Admin::DFT_WORKSPACE}
  Identifier prefix: #{pkg_id_pfx ? pkg_id_pfx : Xolo::Admin::DFT_PKG_ID_PREFIX}

DISPLAY
      end # display config

    end # module prefs
  end # module Admin
end # module Xolo

