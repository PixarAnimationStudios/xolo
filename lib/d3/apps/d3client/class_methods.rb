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

###
module D3

  # Client
  class Client < JSS::Client

    ############### Class Methods #################

    ### Install one or more packages from the command-line
    ### by basename, or edition (or name, filename, id)
    ###
    ### This method is only used by manual installs (i.e. not
    ### automated via d3 sync)
    ###
    ### Basenames always gets the live pkg for that basename
    ###
    ### Editions install the package regardless of status.
    ###
    ### @param pkgs[Array<String,Int>] The packages to install
    ###
    ### @param options[OpenStruct] the d3 client cli options
    ###
    ### @return [void]
    ###
    def self.install(pkgs, options)
      pkgs = [pkgs] if pkgs.is_a? String

      pkgs.each do |pkg_to_search|
        begin
          # get a D3::Package object
          desired_pkg = D3::Package.find_package(pkg_to_search)

          raise JSS::NoSuchItemError, "No d3 package matching #{pkg_to_search}" unless desired_pkg
          raise D3::InstallError, "The package for #{desired_pkg.patch} is missing from the JSS" if desired_pkg.missing?

          if options.custom_expiration
            raise "Sorry #{desired_pkg.patch} is not expirable. A d3 admin needs to add an expiration path." if desired_pkg.expiration_bundle_ids.empty?
          end

          curr_rcpt = D3::Client::Receipt.all[desired_pkg.title]

          # If we were asked to freeze_on_install and the currently installed is
          # same edition, freeze it anyway.
          # Use force to freeze if the currently installed is newer.
          #
          if curr_rcpt && curr_rcpt.id >= desired_pkg.id && options.freeze_on_install
            if options.force || curr_rcpt.id == desired_pkg.id
              freeze_receipts([curr_rcpt.basename]) unless curr_rcpt.frozen?
              D3.log "Freezing previously installed #{curr_rcpt.edition}", :warn
              break
            end # if options.force elsif curr_rcpt.id == desired_pkg.id
            D3.log "Cannot freeze previously installed #{curr_rcpt.edition} (#{curr_rcpt.status}) It is newer than #{desired_pkg.edition}. Use --force if needed.", :warn
            break
          end

          # many things can be forced
          # things that are defined in the pkg itself
          # (exclusions, prohibiting procs, oses, cpus)
          # are checked in the Package#install method
          # These things are the responsibility of the
          # client.
          unless options.force
            # deprecated pkgs need force for installing
            desired_pkg.check_for_deprecated
            # skipped pkgs need force for installing
            desired_pkg.check_for_skipped
            # same or newer?
            desired_pkg.check_for_newer_version

          end # unless options.force

          if curr_rcpt
            D3.log("Un-freezing #{curr_rcpt.patch} by installing #{desired_pkg.patch}", :warn) if curr_rcpt.frozen?

            if  desired_pkg.id == curr_rcpt.id
              D3.log("Re-installing #{desired_pkg.patch}(#{desired_pkg.status})", :warn)
            elsif  desired_pkg.id < curr_rcpt.id
              D3.log("Rolling back #{curr_rcpt.patch}(#{curr_rcpt.status}) to #{desired_pkg.patch}(#{desired_pkg.status})", :warn)
            else
              D3.log("Updating #{curr_rcpt.patch}(#{curr_rcpt.status}) to #{desired_pkg.patch}(#{desired_pkg.status})", :warn)
            end
          end # if curr rcpt

          cloud = cloud_dist_point_to_use(pkg: desired_pkg)

          desired_pkg.install(
            force: options.force,
            admin: get_admin(desired_pkg, options),
            puppywalk: options.puppies,
            expiration: options.custom_expiration,
            verbose: options.verbose,
            alt_download_url: cloud
          )

          freeze_receipts([desired_pkg.basename]) if options.freeze_on_install

          D3.log "Finished installing #{desired_pkg.patch}(#{desired_pkg.status})", :info

        rescue JSS::MissingDataError, JSS::NoSuchItemError, JSS::InvalidDataError, D3::InstallError
          D3.log "Skipping installation of #{pkg_to_search}: #{$ERROR_INFO}", :error
          D3.log_backtrace
        rescue D3::PreInstallError
          D3.log "There was an error with the pre-install script for #{desired_pkg.edition}: #{$ERROR_INFO}", :error
          D3.log_backtrace
        rescue D3::PostInstallError
          D3.log "There was an error with the post-install script for #{desired_pkg.edition}: #{$ERROR_INFO} NOTE: it was installed, but may have problems.", :error
          D3.log_backtrace
        end # begin
      end # args.each
    end # install

    # uninstall one or more packages from the commandline
    #
    # @param pkgs[Array<String,Int>] The packages to uninstall
    #
    # @return [void]
    #
    def self.uninstall(rcpts, options)
      rcpts = [rcpts] if rcpts.is_a? String
      rcpts.each do |rcpt_to_remove|
        begin

          rcpt = D3::Client::Receipt.find_receipt rcpt_to_remove
          raise D3::UninstallError, "No receipt for '#{rcpt_to_remove}', can't uninstall." unless rcpt

          D3.log "Uninstalling #{rcpt.patch}...", :info
          rcpt.uninstall options.verbose, options.force
          D3.log "Finished uninstalling #{rcpt.patch}.", :info

        rescue JSS::MissingDataError, D3::UninstallError, JSS::InvalidDataError
          D3.log "Skipping uninstall of #{rcpt_to_remove}: #{$ERROR_INFO}", :error
          D3.log_backtrace
          next
        end # begin
      end # rcpts.each
    end # uninstall_manual

    ### Return a valid, possibly-default, admin name for
    ### installing a package. Since the admin name is stored in
    ### the packages in the puppy-q, use that one if it's there.
    ###
    ### @param pkg[D3::Package] the pkg being installed, which might contain an
    ###   admin name
    ###
    ### @return [String] a valid admin name to use for the install
    ###
    def self.get_admin(pkg_to_install, options)
      # is this puppy already in the queue? If so,
      # the queue has our admin_name
      if options.puppies && D3::PUPPY_Q.q[pkg_to_install.basename]

        admin = D3::PUPPY_Q.q[pkg_to_install.title].admin
        admin ||= D3::DFT_PUPPY_ADMIN

      # not a puppy pkg
      else
        # start with the cli options
        admin = options.admin
        # then do a lookup if no cli option
        admin ||= D3.admin

      end # if @options.puppies

      admin
    end # get admin name

    ### Remove one or more puppies from the puppy queue
    ###
    ### @param puppies[String, Array<String>] the basenames to remove from the queue
    ###
    ### @return [void]
    ###
    def self.dequeue_puppies(puppies)
      puppies = [puppies] if puppies.is_a? String
      puppies = D3::PUPPY_Q.pups if puppies.include? 'all'
      puppies.each do |pup|
        unless the_puppy = D3::PUPPY_Q.q[pup]
          D3.log "No pkg for title '#{pup}' in the puppy queue.", :warn
          next
        end # unless
        begin
          D3.log "Removing '#{the_puppy.patch}' from the puppy queue.", :warn
          D3::PUPPY_Q - the_puppy
        rescue
          D3.log "Couldn't remove #{the_puppy.edition} from the puppy queue: #{$ERROR_INFO}", :error
        end # begin
      end
    end

    ### Sync this machine
    ###
    ### @param options[OpenStruct] the options from the commandline
    ###
    ### @return [void]
    ###
    def self.sync(options = OpenStruct.new)
      D3::Client.set_env :sync
      D3.log 'Starting sync', :warn

      begin
        # update rcpts
        update_rcpts

        # clean out any invalid puppies from the queue
        clean_doghouse

        # install puppies now?
        do_puppy_queue_installs_from_sync options

        # updates/patches?
        update_installed_pkgs options

        # new auto-installs?
        do_auto_installs options

        # expirations
        do_expirations

        # removie receipts w/ missing packages on the server
        # This must happen AFTER update_installed_pkgs
        # so that the title gets any updates on the server
        # before removing the recetip (which wouild prevent
        # updates)
        clean_missing_receipts

        D3.log 'Finished sync', :warn
      ensure
        D3::Client.unset_env :sync
      end
    end # def sync

    # Update any receipt data that might be changed in the matching package
    # on the server, including:
    # - status
    # - pre- or post-remove scripts
    # - removability
    # - prohibiting processes
    # - expiration details
    #
    # Also update
    # - last usage for expiring pkgs
    #
    # @return [void]
    #
    def self.update_rcpts
      D3.log 'Updating receipts', :warn

      D3::Client::Receipt.all.each do |title, rcpt|
        pkgdata = D3::Package.find_package rcpt.patch, :hash

        unless pkgdata
          # if this pkg is missing, mark it so...
          D3.log "Receipt '#{rcpt.patch}' is missing from d3. Updating receipt.", :info
          rcpt.status = :missing
          rcpt.update
          next
        end
        need_update = false

        # Are we rolling back to a prev version?
        # If the pkgdata[:status] is :pilot and the
        # rcpt.status is NOT :pilot, then we are.
        rolling_back = (pkgdata[:status] == :pilot) && (rcpt.status != :pilot)

        # status
        unless rolling_back
          if rcpt.status != pkgdata[:status]
            # update the status
            rcpt.status = pkgdata[:status]
            D3.log "Updating status for #{rcpt.patch} to #{pkgdata[:status]}", :info
            need_update = true
          end # if
        end # unless

        # pre-remove script
        if rcpt.pre_remove_script_id != pkgdata[:pre_remove_script_id]
          rcpt.pre_remove_script_id = pkgdata[:pre_remove_script_id]
          D3.log "Updating pre-remove script for #{rcpt.patch}", :info
          need_update = true
        end # if

        # post-remove script
        if rcpt.post_remove_script_id != pkgdata[:post_remove_script_id]
          rcpt.post_remove_script_id = pkgdata[:post_remove_script_id]
          D3.log "Updating post-remove script for #{rcpt.patch}", :info
          need_update = true
        end # if

        # removability
        if rcpt.removable? != pkgdata[:removable]
          rcpt.removable = pkgdata[:removable]
          D3.log "Updating removability for #{rcpt.patch}", :info
          unless rcpt.removable?
            rcpt.expiration = 0
            D3.log "#{rcpt.patch} is not expirable now that it's not removable", :info
          end
          need_update = true
        end # if

        # expiration
        if rcpt.removable?

          unless rcpt.expiration_bundle_ids_match? pkgdata[:expiration_bundle_ids]
            rcpt.expiration_bundle_ids = pkgdata[:expiration_bundle_ids]
            D3.log "Updating expiration path(s) for #{rcpt.patch}", :info
            need_update = true
          end # if

          if (rcpt.expiration != pkgdata[:expiration].to_i) && !rcpt.custom_expiration
            rcpt.expiration = pkgdata[:expiration].to_i
            D3.log "Updating expiration for #{rcpt.patch}", :info
            need_update = true
          end # if
        end # if removable

        # prohibiting_processes
        # make sure they are all arrays as of v3.0.12
        unless rcpt.prohibiting_processes.is_a? Array
          rcpt.prohibiting_processes = JSS.to_s_and_a(rcpt.prohibiting_processes)[:arrayform]
          need_update = true
        end
        if rcpt.prohibiting_processes.sort != pkgdata[:prohibiting_processes].sort
          rcpt.prohibiting_processes = pkgdata[:prohibiting_processes]
          D3.log "Updating prohibiting_processes for #{rcpt.patch}", :info
          need_update = true
        end # if

        rcpt.update if need_update
      end # each do title, rcpt
    end # update_rcpts

    # remove any invalid puppies from the queue
    # invalid = id is no longer in d3, or status is missing
    #
    # @return [void]
    #
    def self.clean_doghouse
      D3.log 'Checking for invalid puppies in the queue', :warn
      D3::PUPPY_Q.pending_puppies.each do |basename, pup|
        unless D3::Package.all_ids.include? pup.id
          D3.log "Removing #{pup.patch} from puppy queue: no longer in d3", :info
          D3::PUPPY_Q - pup
          next
        end
        if D3::Package.missing_data.keys.include? pup.id
          D3.log "Removing #{pup.edition} from puppy queue: status is 'missing'", :info
          D3::PUPPY_Q - pup
        end
      end
    end

    ### Install any new live pkgs scoped for autoinstall on this machine.
    ###
    ### @param options[OpenStruct] the options from the commandline
    ###
    ### @return [void]
    ###
    def self.do_auto_installs(options)
      verbose = options.verbose
      force = options.force || D3.forced?
      D3.log 'Checking for new packages to auto-install', :warn
      D3::Client.set_env :auto_install
      begin # for ensure below
        D3::Client::Receipt.basenames :refresh

        # loop through the groups for this machine
        auto_groups = D3::Client.computer_groups.dup
        auto_groups.unshift D3::STANDARD_AUTO_GROUP
        auto_groups.each do |group|
          # this is the intersection of all pkg ids that get auto-installed
          # for the group, and all live pkg ids...
          # meaning this machine should have these pkg ids.
          live_ids_for_group = (D3::Package.live_data.keys & D3::Package.auto_install_ids_for_group(group))

          live_ids_for_group.each do |live_id|
            # skip those not available
            next unless available_pkg_ids.include? live_id

            auto_install_title = D3::Package.live_data[live_id][:title]

            # skip if this title is installed already - it'll be handled with
            # the update_installed_pkgs method during sync.
            next if D3::Client::Receipt.all.keys.include? auto_install_title

            new_pkg = D3::Package.new id: live_id

            if new_pkg.reboot?
              queued_id = puppy_in_queue new_pkg.title
              if queued_id && queued_id >= new_pkg.id
                D3.log "Skipping auto-install of puppy-package #{new_pkg.patch}, there's a newer one in the queue already", :info
                next
              end # if queued_id && queued_id >= new_pkg.id
            end #  if new_pkg.reboot?

            begin
              D3.log "Auto-installing #{new_pkg.basename} for group '#{group}'", :info
              cloud = cloud_dist_point_to_use(pkg: new_pkg)
              new_pkg.install(
                admin: D3::AUTO_INSTALL_ADMIN,
                verbose: verbose,
                force: force,
                puppywalk: options.puppies,
                alt_download_url: cloud
              )
              D3.log "Auto-installed #{new_pkg.title}", :warn
            rescue JSS::MissingDataError, JSS::InvalidDataError, D3::InstallError
              D3.log "Skipping auto-install of #{new_pkg.patch}: #{$!}", :error
              D3.log_backtrace
            rescue D3::PreInstallError
              D3.log "There was an error with the pre-install script for #{new_pkg.patch}: #{$!}", :error
              D3.log_backtrace
            rescue D3::PostInstallError
              D3.log "There was an error with the post-install script for #{new_pkg.patch}: #{$!} NOTE: #{new_pkg.patch} was installed, but may not work.", :error
              D3.log_backtrace
            end # begin
          end # live_ids_for_group.each do |live_id|
        end # each group
      ensure
        D3::Client.unset_env :auto_install
      end
    end

    # remove any receipts for packages that are missing from the server
    #
    #
    def self.clean_missing_receipts
      D3.log "Checking for receipts no longer in d3", :warn
      D3::Client::Receipt.all.values.select{|r| r.status == :missing}.each do |mrcpt|
        D3.log "Removing receipt for missing patch #{mrcpt.patch}", :info
        D3::Client::Receipt.remove_receipt mrcpt.title
        D3.log "Removed receipt for missing patch #{mrcpt.patch}", :info
      end
    end

    # Update any currently installed titles to the currently live one
    # skipping any titles currently frozen
    #
    # @param options[OpenStruct] the options from the commandline
    #
    # @return [void]
    #
    def self.update_installed_pkgs(options)
      verbose = options.verbose
      force = options.force || D3.forced?
      D3.log 'Checking for updates to installed packages', :warn
      D3::Client.set_env :auto_update
      begin # see ensure below

        # get the current list of live titles and the ids of the live patchs
        live_titles_to_ids = D3::Package.titles_to_live_ids

        # loop through the install pkgs
        D3::Client::Receipt.all.values.each do |rcpt|

          # is there a live pkg for this title?
          if live_titles_to_ids[rcpt.title]
            live_id = live_titles_to_ids[rcpt.title]
            live_pkg_data = D3::Package.package_data[live_id]
          else
            D3.log "Skipping update for #{rcpt.patch}: no currently live package for title", :info
            next
          end

          # are we rolling back? Not if the recpt is in pilot.
          if live_pkg_data[:id] < rcpt.id

            if rcpt.pilot?
              D3.log "Skipping rollback of #{live_pkg_data[:patch]}, #{rcpt.patch} is in pilot", :info
              next
            else
              rollback = true
            end
          # no we aren't rolling back
          else
            # skip unless the live id is higher than the rcpt id
            unless live_pkg_data[:id] > rcpt.id
              D3.log "No update for #{rcpt.patch}", :debug
              next
            end
          end

          # skip any frozen receipts
          if rcpt.frozen?
            D3.log "Skipping update check for #{rcpt.patch}(#{rcpt.status}): currently frozen on this machine.", :warn
            next
          end

          # check the puppy queue if needed
          if live_pkg_data[:reboot]
            queued_id = puppy_in_queue(live_pkg_data[:title])
            if queued_id && queued_id >= live_pkg_data[:id]
              D3.log "Skipping auto-update of puppy-queue item #{live_pkg_data[:edition]}, there's a newer one in the queue already", :info
              next
            end # if queued_id && queued_id >= live_pkg.id
          end #  if live_pkg.reboot?

          # mention rollbacks
          if rollback
            D3.log "Rolling back #{rcpt.patch} (#{rcpt.status}) to older live #{live_pkg_data[:patch]}.", :warn
          else
            D3.log "Updating #{rcpt.patch} (#{rcpt.status}) to #{live_pkg_data[:patch]} (#{live_pkg_data[:status]})", :warn
          end

          # are we bringing over a custom expiration period?
          expiration = rcpt.custom_expiration ? rcpt.expiration : nil

          # heres the pkg
          live_pkg = D3::Package.new id: live_basenames_to_ids[rcpt.basename]

          begin
            cloud = cloud_dist_point_to_use(pkg: live_pkg)
            live_pkg.install(
              admin: rcpt.admin,
              expiration: expiration,
              verbose: verbose,
              force: force,
              puppywalk: options.puppies,
              alt_download_url: cloud
            )
            D3.log "Done updating #{rcpt.edition} (#{rcpt.status}) to #{live_pkg.edition} (#{live_pkg.status})", :info
          rescue JSS::MissingDataError, JSS::InvalidDataError, D3::InstallError
            D3.log "Skipping update of #{rcpt.edition} to #{live_pkg.edition}: #{$ERROR_INFO}", :error
            D3.log_backtrace
          rescue D3::PreInstallError
            D3.log "There was an error with the pre-install script for #{live_pkg.edition}: #{$ERROR_INFO}", :error
            D3.log_backtrace
          rescue D3::PostInstallError
            D3.log "There was an error with the post-install script for #{live_pkg.edition}: #{$ERROR_INFO} NOTE: #{live_pkg.edition} was installed, but may not work.", :error
            D3.log_backtrace
          rescue D3::UninstallError
            D3.log "Skipping update of #{rcpt.edition} to #{live_pkg.edition}: There was an error uninstalling the older #{rcpt.edition}: #{$ERROR_INFO}", :error
            D3.log_backtrace
          end # begin
        end # D3::Client::Receipt.all.values.each
      ensure
        D3::Client.unset_env :auto_update
      end # begin..ensure
    end # update installed pkgs

    ### Freeze one or more receipts
    ###
    ### @param basenames[Array] the basenames of the rcpts to freeze
    ###
    ### @return [void]
    ###
    def self.freeze_receipts(basenames)
      basenames.each do |bn|
        rcpt = D3::Client::Receipt.all[bn]
        next unless rcpt
        if rcpt.frozen
          D3.log "Can't freeze receipt for #{rcpt.patch}: already frozen.", :warn
          next
        end
        rcpt.freeze
        rcpt.update
        D3.log "Freezing receipt for #{rcpt.patch}, will not auto-update during sync", :warn
      end
    end # freeze receipts

    ### Thaw one or more receipts
    ###
    ### @param basenames[Array] the basenames of the rcpts to thaw
    ###
    ### @return [void]
    ###
    def self.thaw_receipts(basenames)
      basenames.each do |bn|
        rcpt = D3::Client::Receipt.all[bn]
        next unless rcpt
        unless rcpt.frozen
          D3.log "Can't thaw receipt for #{rcpt.patch}: not frozen.", :warn
          next
        end
        rcpt.thaw
        rcpt.update
        D3.log "Thawing receipt for #{rcpt.patch}, will resume auto-update during sync", :warn
      end
    end # thaw_receipts

    ### forget one or more receipts, and their matching apple pkg receipts
    ###
    ### @param basenames[Array] the basenames of the rcpts to forget
    ###
    ### @return [void]
    ###
    def self.forget_receipts(basenames)
      basenames.each do |bn|
        rcpt = D3::Client::Receipt.all[bn]
        next unless rcpt
        rcpt.apple_pkg_ids.each { |ar| system "/usr/sbin/pkgutil --forget '#{ar}'" }
        D3::Client::Receipt.remove_receipt bn
        D3.log "Receipt for #{rcpt.patch} has been forgotten", :warn
      end
    end # thaw_receipts

    ### Do any pending puppy installs right now, because we're
    ### syncing and --puppies option was given
    ###
    def self.do_puppy_queue_installs_from_sync(options)
      return unless options.puppies
      return if D3::PUPPY_Q.q.empty?
      D3.log 'Installing all pkgs from puppy-queue during sync with --puppies', :info
      D3::PUPPY_Q.q.each do |basename, puppy|
        begin
          D3.log "Installing #{puppy.edition} from puppy-queue during sync with --puppies", :debug
          new_pkg = D3::Package.new id: puppy.id
          cloud = cloud_dist_point_to_use(pkg: new_pkg)
          new_pkg.install(
            admin: puppy.admin,
            verbose: options.verbose,
            force: puppy.force,
            puppywalk: true,
            expiration: puppy.expiration,
            alt_download_url: cloud
          )

          D3::PUPPY_Q - puppy
        rescue JSS::NoSuchItemError
          D3.log "Skipping install of #{new_pkg.patch} from queue:\n   no longer in d3.", :error
          D3.log_backtrace
          D3::PUPPY_Q - puppy
        rescue JSS::MissingDataError, JSS::InvalidDataError, D3::InstallError
          D3.log "Skipping install of #{new_pkg.edition} from queue: #{$ERROR_INFO}", :error
          D3.log_backtrace
        rescue D3::PreInstallError
          D3.log "There was an error with the pre-install script for #{new_pkg.edition}: #{$ERROR_INFO}", :error
          D3.log_backtrace
        rescue D3::PostInstallError
          D3.log "There was an error with the post-install script for #{new_pkg.edition}: #{$ERROR_INFO} NOTE: #{new_pkg.edition} was installed, but may not work.", :error
          D3.log_backtrace
          D3::PUPPY_Q - puppy
        end # begin
      end # each do puppy
    end

    # Was the --no-puppy-notification option given by the admin?
    #
    # @return [Boolean]
    #
    def self.puppy_notification_ok_with_admin?
      @@puppy_notification_ok_with_admin
    end

    # Set the --no-puppy-notification option as given by the admin
    #
    # @param bool[Boolean] did the admin give the option?
    #
    # @return [void]
    #
    def self.puppy_notification_ok_with_admin= (bool)
      @@puppy_notification_ok_with_admin = bool
    end

    # Expire any pkgs that are due for expiration,
    # and if any are expired, run the expiration policy.
    #
    # @param verbose[Boolean] should operations be verbose?
    #
    # @param force[Boolean] should operations be forced?
    #
    # @return [void]
    #
    def self.do_expirations (verbose = false, force = D3.forced?)
      @@editions_expired = []
      D3.log 'Starting expiration check', :warn

      D3::Client::Receipt.all.values.each do |rcpt|
        begin
          # rcpt.expire only does anything if expiration is appropriate.
          expired_patch = rcpt.expire verbose, force
          @@patchs_expired << expired_patch if expired_patch
        rescue
          D3.log "There was an error expiring #{rcpt.edition}: #{$ERROR_INFO}", :error
          D3.log_backtrace
        end
      end

      return true if @@patchs_expired.empty?

      D3::Client.set_env :finished_expirations, @@editions_expired.join(' ')

      if policy = D3::CONFIG.client_expiration_policy
        D3.run_policy policy, :expiration, verbose
      end # if D3::CONFIG.client exp policy

      D3::Client.unset_env :finished_expirations
      @@patchs_expired = []
    end

    ### An array of package ids that are available for installing
    ### or piloting (i.e. not excluded, right OS, right cpu) for this machine.
    ###
    ### @param refresh[Boolean] re-read the data from the server?
    ###
    ### @return [Array<Integer>]
    ###
    def self.available_pkg_ids(refresh = false)
      @@available_pkg_ids = nil if refresh
      return @@available_pkg_ids if @@available_pkg_ids

      computer_groups(:refresh) if refresh

      my_cpu = `/usr/bin/uname -p`
      my_os = `/usr/bin/sw_vers -productVersion`.chomp

      @@available_pkg_ids = []

      D3::Package.package_data.values.each do |pkg|
        next unless JSS.os_ok? pkg[:oses], my_os
        next unless JSS.processor_ok? pkg[:required_processor], my_cpu
        @@available_pkg_ids << pkg[:id] if (pkg[:excluded_groups] & computer_groups).empty?
      end # do pkg
      @@available_pkg_ids
    end

    ### An array of JSS::ComputerGroup names to which this computer belongs
    ###
    ### @param refresh[Boolean] re-read the data from the server?
    ###
    ### @return [Array<String>] the JSS groups to which this machine belongs
    ###
    def self.computer_groups(refresh = false)
      @@computer_groups = nil if refresh
      return @@computer_groups if @@computer_groups
      @@computer_groups = JSS::Computer.new(udid: JSS::Client.udid).computer_groups
    end

    ### The cloud dist point to use for installs
    ### Returns a URL if:
    ###   - current dist point isn't reachable for downloads
    ###   - D3::CONFIG.client_try_cloud_distpoint is true
    ###   - a Cloud Dist Point is defined in the JSS
    ###
    ### otherwise nil
    ###
    ### @return [String, nil] The download url for the cloud dist point,
    ###   if we should use one, or nil.
    ###
    def self.cloud_dist_point_to_use(refresh = false, pkg: nil)
      raise 'You must provide a pkg' unless pkg.is_a? D3::Package

      @@cloud_dist_url == :unknown if refresh

      mdp = JSS::DistributionPoint.my_distribution_point

      # Should we try a cloud distribution point if the primary is unavailable ?
      unless D3::CONFIG.client_try_cloud_distpoint
        D3.log "Config is not to try cloud, using only Distribution Point '#{mdp.name}'", :info
        return @@cloud_dist_url = nil
      end

      # Can we reach the primary distribution point? Return nil if true.
      if mdp.reachable_for_download?(get_ro_pass(:http)) || mdp.reachable_for_download?(get_ro_pass(:dist))
        D3.log "Distribution Point '#{mdp.name}' is reachable, no need for cloud", :info
        return @@cloud_dist_url = nil
      end

      # Get the cloud distribution point defined in the JSS
      cloud_url = cloud_distribution_point_url
      unless cloud_url
        D3.log 'No cloud distribution URL found.', :info
        return @@cloud_dist_url = nil
      end
      # Make sure the package is available on the cloud distribution point
      pkg_available = validate_pkg_in_cloud(cloud_url, pkg) if cloud_url
      unless pkg_available
        D3.log "#{pkg.edition} is not available in the cloud", :info
        return @@cloud_dist_url = nil
      end

      @@cloud_dist_url = cloud_url
    end # self.cloud_dist_point_to_use

    # given a cloud url and a D3::Package
    # is the pkg available at that url?
    #
    # @return [Boolean]
    #
    def self.validate_pkg_in_cloud(url, pkg)
      full_url = "#{url}/#{pkg.filename}"
      dummy_install_target = Pathname.new('/Volumes/' + Time.now.asctime)
      jamf_cmd = "#{JSS::Client::JAMF_BINARY} install -package #{Shellwords.escape pkg.filename} -path #{Shellwords.escape full_url} -target #{Shellwords.escape dummy_install_target}/ -showProgress -verbose"
      Open3.popen2e(jamf_cmd) do |_stdin, stdout_err, wait_thr|
        stdout_err.each do |line|
          if /^\d*+\.\d*+% / =~ line
            Process.kill('KILL', wait_thr.pid)
            return true
          end # end if /^\d*+\.\d*+% / =~ line
        end # end stdout_err.each do |line|
        return false
      end # end Open3.popen2e(jamf_cmd) do |_stdin, stdout_err, wait_thr|
    end # def self.validate_pkg_in_cloud pkg

    ### Is a Cloud Distribution Point available for pkg downloads?
    ### If so, return the url for downloading pkg files
    ### (the filename will be appended during install)
    ###
    ### @return [String, nil]
    ###
    def self.cloud_distribution_point_url
      result = JSS::DB_CNX.db.query 'SELECT download_url, cdn_url FROM cloud_distribution_point'
      urls = result.fetch
      result.free
      return nil if urls.nil?
      return nil if urls[0].empty? || urls[1].empty?
      urls[0].empty? ? urls[1] : urls[0]
    end

    ### Given a basename, is any edition of it in the puppy queue?
    ### If so, return the id of the queued pkg, else return nil
    ###
    ### @param basename[String]
    ###
    ### @return [Integer, nil] The id of the queued package for the basename, if any
    ###
    def self.puppy_in_queue(basename)
      pup = D3::PUPPY_Q.queue[basename]
      return nil unless pup
      pup.id
    end # basename in puppy queue

    ### get the executable path of the current foreground GUI app. NOTE, if you
    ### have fast user switching on, or multi-user screensharing,
    ### this only gets the one currenly using the physical console
    ###
    ### @return [Pathname, nil] the path to the executable of the current foreground app, nil if none
    ###
    def self.foreground_executable_path
      lsai = '/usr/bin/lsappinfo'
      ls_app_id = `#{lsai} front`.chomp
      return nil if ls_app_id == '[ NULL ] '

      raw = `#{lsai} info -only executablepath '#{ls_app_id}'`.chomp
      return nil if raw.empty?

      path = raw.split(/=\s*"/).last
      return nil unless path
      path.chomp!('"')
      path.empty? ? nil : Pathname.new(path)
    end

  end # class

end # module D3
