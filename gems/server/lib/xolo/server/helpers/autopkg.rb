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

        # when we find a .pkg after a recipe has run, it can't be older than this many
        # seconds, or we assume it is from some other run of the recipe, not the one we
        # just did. Currently 20 min
        MAX_PKG_AGE = 1200

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

        # Is AutoPkg integration enabled for the server?
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

        # the autopkg report-plist path, based on the
        # title name & timestamp w/nanosecs
        # @return [Pathname]
        ##############################
        def autopkg_report_plist_path
          @autopkg_report_plist_path ||= Pathname.new "/tmp/xolo-autopkg-report-#{@title_id_for_autopkg}-#{Time.now.strftime('%s%N')}.plist"
        end

        # Given a Hash or Array, recursively look for a
        # Hash Key :version and return the value.
        # Returns the first such key it finds.
        #
        # @param collection [Hash, Array] the data to search
        #
        # @return [String, nil] the first 'version' value found, or nil if not found
        ###########################
        def find_version(collection)
          version = nil

          if collection.is_a? Hash
            collection.each do |key, value|
              if key == :version
                version = value
                break
              end
              version = find_version(value) if value.is_a?(Hash) || value.is_a?(Array)
              break if version
            end
          elsif collection.is_a? Array
            collection.each do |value|
              version = find_version(value) if value.is_a?(Hash) || value.is_a?(Array)
              break if version
            end
          end # if collection.is_a

          version
        end # def

        # the autopkg run command for this title
        #####################################
        def autopkg_run_command(title_object)
          # is autopkg enabled for the server as a whole?
          return unless autopkg_enabled?

          # is autopkg enabled for this title?
          return unless title_object.autopkg_enabled?

          [
            '/bin/launchctl',
            'asuser',
            autopkg_user_entry.uid.to_s,
            'sudo',
            '-u',
            Xolo::Server.config.autopkg_user,
            Xolo::Server.config.autopkg_executable,
            'run',
            '--verbose',
            title_object.autopkg_recipe,
            FAIL_UNTRUSTED_RECIPES_CLI_OPT,
            '--report-plist',
            autopkg_report_plist_path.to_s
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
          # is autopkg enabled for this title?
          return unless title_object.autopkg_enabled?

          # Make this available to other methods here
          @title_id_for_autopkg = title_object.title

          recipe = title_object.autopkg_recipe
          pkgdir = Pathname.new title_object.autopkg_dir
          clean_old_pkgs pkgdir

          cmd = autopkg_run_command(title_object)
          progress "Running AutoPkg recipe '#{recipe}' for #{title_object.title}..."
          log_info "Running AutoPkg recipe for #{title_object.title} via command: #{cmd.join(' ')}"

          unlock_autopkg_user_keychain
          souterr, status = Open3.capture2e(*cmd)
          souterr.strip!

          if status.success?
            msg = "AutoPkg recipe '#{recipe}' for title '#{title_object.title}' completed successfully."
            progress msg, log: :info, alert: true

            log_debug 'AutoPkg output:'
            souterr.lines.each { |l| log_debug "AutoPkg: #{l.chomp}" }

            pkgs = pkgdir.children.select { |c| c.extname == '.pkg' }
            # the Pathname of the newest .pkg
            pkgs.max_by(&:mtime)

          # Failure is a option
          else
            handle_failed_recipe(
              recipe: recipe,
              title_object: title_object,
              status: status,
              souterr: souterr
            )
          end
        end

        # Deal with a failed recipe run
        #
        ###############################
        def handle_failed_recipe(recipe:, title_object:, status:, souterr:)
          errmsg = "ERROR: AutoPkg recipe '#{recipe}' for title '#{title_object.title}' failed with status #{status.exitstatus}. Details logged and emailed to '#{title_object.contact_email}'"

          progress errmsg, log: :error, alert: true

          # log the details
          log_error 'AutoPkg output:'
          souterr.lines.each { |l| log_error "AutoPkg: #{l.chomp}" }

          # email the details to the contact addr for the title
          email_subj = "ERROR: AutoPkg recipe FAILED for title '#{title_object.title}'"
          email_msg = <<~ENDEMAIL
            The autopkg recipe '#{recipe}' for title '#{title_object.title}' failed with status #{status.exitstatus}.

            Please check that the recipe is up to date. If not, please update the recipe's repo by running this as the autppkg user on the xolo server:

               autopkg repo-update <repo-name>

            Then confirm you still trust the recipe.
            If so, run:

               autopkg update-trust-info '#{recipe}'

            Then tell xolo the xolo server to re-run the recipe - the .pkg will always be assigned to the latest version.

               xadm rerun-autopkg-recipe #{title_object.title}

            If needed, contact your xoloserver administrator to perform the autopkg commands.

            Here is the output from the failed recipe:
            ------------------------------------------
            #{souterr}
          ENDEMAIL

          send_email to: title_object.contact_email, subject: email_subj, msg: email_msg, html: false

          raise "AutoPkg recipe #{recipe} failed."
        end

        # confirm a given autopkg package is OK to use after running a recipe
        ###########################
        def validate_autopkg_pkg(pkg_src, desired_version)
          if pkg_src.nil?
            msg = 'No pkg was found after running the autopkg recipe. Please check the AutoPkg recipe and the server log for details. Make sure the --autopkg-dir is correct. Nothing to upload.'
            progress msg, log: :warn, alert: true
            return false
          end

          oldest_allowed = Time.now - MAX_PKG_AGE # 20 minutes ago
          if pkg_src.mtime < oldest_allowed
            msg = "A pkg was found after running the autopkg recipe, but it was last modified at #{pkg_src.mtime}, which is more than 20 minutes ago. To avoid accidentally uploading an old pkg, the server will not upload this pkg. Please check the AutoPkg recipe and the server log for details. Nothing to upload"
            progress msg, log: :warn, alert: true
            return false
          end

          fetched_version =
            if autopkg_report_plist_path.file?
              json_report = `/usr/bin/plutil -convert json #{autopkg_report_plist_path.pix_shellescape} -o -`
              report = JSON.parse json_report, symbolize_names: true
              find_version report[:summary_results]
            end

          if fetched_version != desired_version
            msg = "A pkg was found after running the recipe, but the version that was fetched was '#{fetched_version}', and we were expecting version '#{desired_version}'. Nothing to upload"
            progress msg, log: :warn, alert: true
            return false
          end

          true
        end

        # remove any existing pkgs from the given autopkg output dir
        #
        # @param pkgdir[Pathname] the directory to clean
        # @return [void]
        ##################
        def clean_old_pkgs(pkgdir)
          log_debug "Removing .pkg files from #{pkgdir} before running autopkg recipe"
          pkgdir.children.each { |c| c.delete if c.extname == '.pkg' }
        end

      end # AutoPkg

    end # Helpers

  end # Server

end # module Xolo
