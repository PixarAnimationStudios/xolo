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

    module Mixins

      # This is mixed in to Xolo::Server::Title
      #
      #
      # - unlock autpkg_user's login keychain if pw is in config
      # - run recipe
      # - move pkg to workspace
      # - sign pkg if needed
      # - wrap and re-sign if needed
      # - rename pkg
      # - upload to Jamf Pro
      #
      module AutoPkg

        # Constants
        #######################
        #######################

        FAIL_UNTRUSTED_RECIPES_CLI_OPT = '-k FAIL_RECIPES_WITHOUT_TRUST_INFO=yes'

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

        # The Etc::Passwd entry for the autopkg_user
        ###############################
        def autopkg_user_entry
          return unless Xolo::Server.config.autopkg_user

          @autopkg_user_entry ||= Etc.getpwnam(Xolo::Server.config.autopkg_user)
        rescue ArgumentError
          nil
        end

        # unlock the autopkg_user's login keychain if a password is provided in the config
        # This is necessary if any recipes need to access it for signing identities
        ###############################
        def unlock_autopkg_user_keychain
          return unless autopkg_enabled?
          return unless Xolo::Server.config.autopkg_user_keychain_pw

          keychain_path = "#{autopkg_user_entry.dir}/Library/Keychains/login.keychain-db"
          cmd = [
            'unlock-keychain',
            '-p',
            Xolo::Server.config.autopkg_user_keychain_pw,
            keychain_path
          ]
          run_security(cmd.map { |i| security_escape i }.join(' '))
        end

        # Is AutoPkg integration enabled?
        ###############################
        def autopkg_enabled?
          return @autopkg_enabled if defined?(@autopkg_enabled)

          @autopkg_enabled =
            Xolo::Server.config.autopkg_executable && \
            Pathname.new(Xolo::Server.config.autopkg_executable).executable? && \
            autopkg_user_entry && \
            true
        rescue ArgumentError
          @autopkg_enabled = false
        end

        # the autopkg run command for this title
        #####################################
        def autopkg_run_command
          return unless autopkg_enabled?

          [
            '/bin/launchctl',
            'asuser',
            autopkg_user_entry.uid.to_s,
            'sudo',
            '-u',
            Xolo::Server.config.autopkg_user,
            Xolo::Server.config.autopkg_executable.shellescape,
            'run',
            autopkg_recipe.shellescape,
            FAIL_UNTRUSTED_RECIPES_CLI_OPT
          ]
        end

        #
        ##############################
        def run_autopkg_recipe
          return unless autopkg_recipe && autopkg_dir

          cmd = autopkg_run_command
          log_info "Running AutoPkg recipe for #{title} via command: #{cmd.join(' ')}"

          souterr, status = Open3.capture2e(*cmd)
          souterr.strip!

          if status.success?
            log_info "AutoPkg recipe #{autopkg_recipe} completed successfully.", alert: true
            log_debug "AutoPkg output:\n#{souterr}"
          else

            log_error "AutoPkg recipe #{autopkg_recipe} failed with status #{status.exitstatus}.", alert: true
            log_error "AutoPkg output:\n#{souterr}"
            raise "AutoPkg recipe #{autopkg_recipe} failed."
          end
        end

        # @return [Pathname, nil] the latest pkg file in the autopkg_dir
        ##############################
        def latest_autopkg_pkg
          ap_dir = Pathname.new(autopkg_dir)
          pkgs = ap_dir.children.select { |c| c.extname == '.pkg' }
          pkgs.max_by { |p| p.mtime }
        end

        #
        ##############################
        def upload_pkg_to_jamf_from_autopkg
          nil
        end

        # Handle a pkg from autopkg
        # move to file_transfers?
        ###########################################
        def process_autopkg_pkg(_pkg_file)
          nil
        end

      end # AutoPkg

    end # Helpers

  end # Server

end # module Xolo
