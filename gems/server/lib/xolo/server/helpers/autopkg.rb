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

      # This is mixed in to Xolo::Server as a helper module, so its
      # instance methods are available in sinatra routes and views.
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

        AUTOPKG_UPLOADED_BY = 'autopkg'
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
        def autopkg_run_command(title_object)
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
            '--verbose',
            title_object.autopkg_recipe.shellescape,
            FAIL_UNTRUSTED_RECIPES_CLI_OPT
          ]
        end

        # Run the AutoPkg recipe for this title
        # return the Pathname to the latest pkg in the autopkg_dir
        #
        # @param title_object [Xolo::Server::Title] the title object for which to run the recipe.
        #   It must have an autopkg_recipe defined.
        # @return [Pathname, nil] the latest pkg file in the autopkg_dir after running the recipe,
        #   or nil if the recipe is not enabled for this title
        ##############################
        def run_autopkg_recipe(title_object)
          return unless autopkg_enabled?
          return unless title_object.autopkg_recipe && title_object.autopkg_dir

          recipe = title_object.autopkg_recipe
          pkgdir = Pathname.new title_object.autopkg_dir

          cmd = autopkg_run_command(title_object)
          progress "Running AutoPkg recipe for #{title_object.title} via command: #{cmd.join(' ')}", log: :info

          unlock_autopkg_user_keychain

          souterr, status = Open3.capture2e(*cmd)
          souterr.strip!

          if status.success?
            progress "AutoPkg recipe #{recipe} completed successfully.", log: :info, alert: true
            log_debug 'AutoPkg output:'
            souterr.lines.each { |l| log_debug "AutoPkg: #{l.chomp}" }

            pkgs = pkgdir.children.select { |c| c.extname == '.pkg' }
            pkgs.max_by { |p| p.mtime }

          else
            progress "ERROR: AutoPkg recipe #{autopkg_recipe} failed with status #{status.exitstatus}.", log: :error, alert: true
            log_error 'AutoPkg output:'
            souterr.lines.each { |l| log_error "AutoPkg: #{l.chomp}" }

            raise "AutoPkg recipe #{autopkg_recipe} failed."
          end
        end

        # @param version_object [Xolo::Server::Version] the version object for which to upload the pkg.
        # @param new_pkg [Pathname] the pkg to upload to Jamf Pro. This is expected to be the output of run_autopkg_recipe.
        #
        # @return [void]
        ##############################
        def upload_pkg_to_jamf_from_autopkg(version_object, new_pkg)
          # The uploaded pkg from autopkg will be staged here before uploading again to
          # the Jamf Dist Point(s)
          version_object.data_dir.mkpath unless version_object.data_dir.directory?

          # wrap in dist pkg if needed before staging
          new_pkg = wrap_component_pkg_in_distribution(new_pkg) if Xolo::Server.config.create_distribution_pkgs && !pkg_is_distribution?(new_pkg)

          # the name it'll have on the dist server
          staged_pkg = version_object.data_dir + "#{jamf_pkg_name}.pkg"

          # remove any old one that might be there
          staged_pkg.delete if staged_pkg.file?

          # sign pkg if needed
          # this puts the signed pkg in the staging location
          if Xolo::Server.config.sign_autopkg_pkgs && need_to_sign?(new_pkg)
            unlock_autopkg_user_keychain
            sign_pkg(new_pkg, staged_pkg)

          # otherwise just move it to the staging location
          else
            new_pkg.rename(staged_pkg)
          end

          # upload to Jamf Pro
          upload_to_dist_point(version_object.jamf_package, staged_pkg)
        ensure
          orig_new_pkg.delete if defined?(orig_new_pkg) && orig_new_pkg&.file?
          new_pkg.delete if new_pkg&.file?
          staged_pkg.delete if staged_pkg&.file?
        end

      end # AutoPkg

    end # Helpers

  end # Server

end # module Xolo
