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
      # and in Xolo::Server::Title and Xolo::Server::Version,
      # for simplified access to the main server logger, with access to session IDs
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
        ###############################
        def unlock_autopkg_user_keychain
          return unless autopkg_enabled?
          return unless Xolo::Server.config.autopkg_user_keychain_pw

          keychain_path = "#{autopkg_user_entry.dir}/Library/Keychains/login.keychain-db".shellescape
          cmd = [
            '/usr/bin/security',
            'unlock-keychain',
            keychain_path
          ]
          output = nil
          status = nil
          Open3.popen2e(*cmd) do |stdin, stdout_and_stderr, wait_thread|
            stdin.puts ppp
            output = stdout_and_stderr.read
            status = wait_thread.value
          end
          $CHILD_STATUS = status # ensure $? is set correctly
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
          [
            '/bin/launchctl',
            'asuser',
            autopkg_user_entry.uid.to_s,
            'sudo',
            '-u',
            Xolo::Server.config.autopkg_user,
            Xolo::Server.config.autopkg_executable,
            'run',
            autopkg_recipe,
            FAIL_UNTRUSTED_RECIPES_CLI_OPT
          ]
        end

        #
        ##############################
        def run_autopkg_recipe
          return unless autopkg_recipe && autopkg_dir

          cmd = autopkg_run_command
          log_info "Running AutoPkg recipe via command: #{cmd.join(' ')}"

          # TODO: notifications
          souterr, status = Open3.capture2e(*cmd)
          souterr.strip!

          if status.success?
            log_info "AutoPkg recipe #{autopkg_recipe} completed successfully."
            log_debug "AutoPkg output:\n#{souterr}"
          else

            log_error "AutoPkg recipe #{autopkg_recipe} failed with status #{status.exitstatus}."
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
        def upload_pkg_to_jamf_via_autopkg
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
