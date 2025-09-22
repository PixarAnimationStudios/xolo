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

      # This is mixed in to Xolo::Server::Version
      # to define Version-related access to the Jamf Pro server
      #
      module VersionJamfAccess

        # Constants
        #
        ##############################
        ##############################

        # The group of macs with this version installed
        # is named the full prefix plus this suffix.
        JAMF_SMART_GROUP_NAME_INSTALLED_SFX = '-installed'

        # The policy that does initial installs on-demand
        # (via 'xolo install <title> <version') is named the full
        # prefix plus this suffix.
        JAMF_POLICY_NAME_MANUAL_INSTALL_SFX = '-manual-install'

        # The policy that does auto-installs is named the full
        # prefix plus this suffix.
        # The scope is changed as needed when a version's status
        # changes
        JAMF_POLICY_NAME_AUTO_INSTALL_SFX = '-auto-install'

        # The policy that does auto-re-installs is named the full
        # prefix plus this suffix.
        # The scope is changed as needed when a version's status
        # changes
        JAMF_POLICY_NAME_AUTO_REINSTALL_SFX = '-auto-reinstall'

        # POLICIES, PATCH POLICIES, SCOPING
        #############################
        #
        # SMART GROUPS
        # For each title there will be a smart group containing all macs that have any version
        # of the title installed. The smart group will be named 'xolo-<title>-installed'
        #
        # It will be used as an exclusion for the auto-initial-installation policy for each version
        # since if the title is installed at all, any installation is not 'initial' but an update, and
        # will be handled by the Patch Policy.
        #
        # Since there is one per title, it's name is stored in the title object's #jamf_installed_group_name
        # attribute, and the title object has has the method for creating it.
        # It will be created when the first version is added to the title.
        #
        # POLICIES
        # Each version gets two policies for initial installation
        #
        # - one for auto-installs called 'xolo-<title>-<version>-auto-install'
        #   - xolo server maintains the scope as needed
        #     - Targeted to pilot-groups first, then  release-groups when released
        #     - Excluded for excluded groups and frozen-groups
        #   - never in self service
        #
        # - one for manual installs called 'xolo-<title>-<version>-manual-install'
        #   and self-service installs
        #   - xolo server maintains the scope as needed
        #     - Targeted to all with this trigger xolo-install-<target>-<version>
        #     - Excluded for excluded groups and frozen-groups
        #     - the xolo client will determine which is released when
        #       running 'xolo install <title>'
        #
        # NOTE: Other install policies can be created manually for other purposes, just
        # don't name them with xolo-ish names
        #
        # PATCH POLICIES
        # Each version gets one patch policy
        #
        # The patch policy is first scoped targeted to pilot groups.
        # Excluded for excluded groups and frozen-groups
        #
        # When the version is released, the scope is changed to All
        #
        # NOTE: remember that patch polices are pre-limited to only 'eligible'
        # machines - those that have a lower version installed and meet other
        # conditions.
        #
        # But.... questions...
        #
        #  Should it act like d3, and auto-install updates always?
        # def. for auto-install groups... but how about for the general
        # populace, like those who installed initially via SSvc?? Should it
        # auto-update, or notify them to do it in SSvc?
        #
        # If d3-like behaviour:
        # - it auto-installs for anyone who has any version installed
        # - at first, scoped to any pilot-groups, they'll get the latest version
        # - when released, re-scoped to 'all' (see note below)
        #
        #
        # NOTE: Other patch policies can be created manually for other purposes, just
        # don't name them with xolo-ish names
        #
        #####################
        #
        # install live
        #  => xolo install title
        #
        # runs 'jamf policy -trigger xolo-install-current-<title>'
        # the xolo server maintains the trigger
        #################
        #
        # install pilot
        #  => xolo install title version
        #
        # runs 'jamf policy -trigger xolo-install-<title>-<version>'
        # the xolo server maintains the trigger
        ##################
        #
        # auto-install on pilot groups or target groups
        #  => xolo sync
        #
        # runs 'jamf policy'
        # the xolo server maintains the scopes for the policies
        # patch policies will be run as needed
        ##################
        #
        # get the lates JSON data about titles and versions
        # => xolo update
        #
        # runs 'jamf policy -trigger xolo-update'
        # the xolo server maintains a package that deploys the JSON file
        ##################
        #
        # list available titles or versions
        #  => xolo list-titles
        #
        # reads from a local JSON file of title & version data
        # maintained by the xolo server and pushed out via
        # a checkin policy
        ##################

        # Module methods
        #
        # These are available as module methods but not as 'helper'
        # methods in sinatra routes & views.
        #
        ##############################
        ##############################

        # when this module is included
        ##############################
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # when this module is extended
        def self.extended(extender)
          Xolo.verbose_extend extender, self
        end

        # Instance methods
        #
        # These are available directly in sinatra routes and views
        #
        ##############################

        #######  The Xolo Version itself
        ###########################################
        ###########################################

        # Create everything we need in Jamf
        ############################
        def create_in_jamf
          # this will create the JPackage object
          jamf_package

          # This wil create the installed smart group
          jamf_installed_group

          # these will create the policies
          jamf_auto_install_policy
          jamf_manual_install_policy
          jamf_auto_reinstall_policy

          activate_patch_version_in_jamf
        end

        # Apply edits to the Xolo version to Jamf as needed
        # This includes scope changes in policies, changes to pkg 'reboot' setting
        # and changes to pkg 'os_requirements'
        # Uploading a new .pkg installer happen separately
        #########################################
        def update_version_in_jamf
          update_pilot_groups if changes_for_update&.key? :pilot_groups
          update_release_groups(ttl_obj: title_object) if changes_for_update&.key? :release_groups
          update_excluded_groups(ttl_obj: title_object) if changes_for_update&.key? :excluded_groups

          update_jamf_pkg_reboot if changes_for_update&.key? :reboot
          update_jamf_pkg_min_os if changes_for_update&.key? :min_os

          # TODO: Update the critera for the jamf_installed_group IF the title
          # has changed how it determines installed versions, e.g. by adding or
          # changing a version_script or app_bundle_id
          # Changing those is very rare, and ill-advised, so we can skip that for now.
        end

        # Delete an entire version from Jamf Pro
        # This includes the package, the manual install policy, the auto install policy,
        # and the patch policy.
        #
        # @return [void]
        #
        #########################
        def delete_version_from_jamf
          log_debug "Deleting Version '#{version}' from Jamf"

          # The Policies
          pols = [jamf_manual_install_policy, jamf_auto_install_policy, jamf_auto_reinstall_policy, jamf_patch_policy]
          pols.each do |pol|
            next unless pol

            progress "Jamf: Deleting #{pol.class} '#{pol.name}'", log: :info
            pol.delete
          end

          # The Installed Group
          if jamf_installed_group
            progress "Jamf: Deleting #{jamf_installed_group.class} '#{jamf_installed_group.name}'", log: :info
            jamf_installed_group.delete
          end

          # Delete package object
          # This is slow and it blocks, so do it in a thread and update progress every
          # 15 secs
          return unless Jamf::JPackage.valid_id packageName: jamf_pkg_name, cnx: jamf_cnx

          delete_jamf_package

          # The code below is used when we want real-time progress updates to xadm
          # while deletion is happening. It's slow, so we're not using it now.

          # msg = "Jamf: Starting deletion of Package '#{jamf_pkg_name}' id #{jamf_pkg_id} at #{Time.now.strftime '%F %T'}..."
          # progress msg, log: :debug

          # # do this in another thread, so we can report the progress while its happening
          # pkg_del_thr = Thread.new { Jamf::JPackage.fetch(packageName: jamf_pkg_name, cnx: jamf_cnx).delete }
          # pkg_del_thr.name = "package-deletion-thread-#{session[:xolo_id]}"
          # sleep 15
          # while pkg_del_thr.alive?
          #   progress "... #{Time.now.strftime '%F %T'} still deleting, this is slow, sorry."
          #   sleep 15
          # end

          # msg = "Jamf: Deleted Package '#{jamf_pkg_name}' id #{jamf_pkg_id} at  #{Time.now.strftime '%F %T'}"
          # progress msg, log: :debug
        end

        #######  The Jamf Package Object
        ###########################################
        ###########################################

        # Create or fetch the Jamf::JPackage object for this version
        # Returns nil if the package doesn't exist and we're deleting
        #
        # @return [Jamf::JPackage] the Package object associated with this version
        ######################
        def jamf_package
          return @jamf_package if @jamf_package

          id = jamf_pkg_id || Jamf::JPackage.valid_id(name: jamf_pkg_name, cnx: jamf_cnx)
          @jamf_package =
            if id
              log_debug "Jamf: Fetching Jamf::JPackage '#{id}'"
              Jamf::JPackage.fetch id: id, cnx: jamf_cnx
            else
              return if deleting?

              create_jamf_package
            end
        end

        # @return [Jamf::JPackage] Create the Jamf::JPackage object for this version and return it
        #########################
        def create_jamf_package
          progress "Jamf: Creating Package object '#{jamf_pkg_name}'", log: :info

          # The filename is temporary, and will be replaced when the file is uploaded
          pkg = Jamf::JPackage.create(
            cnx: jamf_cnx,
            packageName: jamf_pkg_name,
            fileName: "#{jamf_pkg_name}.pkg",
            rebootRequired: reboot,
            notes: jamf_package_notes,
            categoryId: jamf_xolo_category_id,
            osRequirements: ">=#{min_os}"
          )

          # TODO: Implement max_os, either here, or by maintaining a smart group?
          # I really wish jamf would improve how package objects handle
          # OS requirements, building in the concept of min/max

          self.jamf_pkg_id = pkg.save
          # save the data now so the pkg_id is available for immeadiate use, e.g. by pkg upload
          save_local_data
          pkg
        rescue => e
          msg = "Jamf: Failed to create Jamf::JPackage '#{jamf_pkg_name}': #{e.class}: #{e}"
          log_error msg
          raise Xolo::ServerError, msg
        end

        # @return [String] the 'notes' text for the Jamf::JPackage object for this version
        #############################
        def jamf_package_notes
          pkg_notes = Xolo::Server::Version::JAMF_PKG_NOTES_PREFIX.sub(
            Xolo::Server::Version::JAMF_PKG_NOTES_VERS_PH,
            version
          )
          pkg_notes.sub!(
            Xolo::Server::Version::JAMF_PKG_NOTES_TITLE_PH,
            title
          )
          pkg_notes << title_object.description
          pkg_notes
        end

        # update the reboot setting for the Jamf::JPackage
        # @return [void]
        ##########################
        def update_jamf_pkg_reboot
          new_reboot = changes_for_update&.key?(:reboot) ? changes_for_update[:reboot][:new] : reboot
          progress "Jamf: Updating reboot setting for Jamf::JPackage '#{jamf_pkg_name}' to '#{new_reboot}'", log: :debug
          jamf_package.rebootRequired = new_reboot
          jamf_package.save
        end

        # update the min_os setting for the Jamf::JPackage
        # @return [void]
        ##########################
        def update_jamf_pkg_min_os
          new_min = changes_for_update&.key?(:min_os) ? changes_for_update[:min_os][:new] : min_os
          progress "Jamf: Updating os_requirement for Jamf::JPackage '#{jamf_pkg_name}' to '#{new_min}'",
                   log: :debug
          jamf_package.osRequirements = ">=#{new_min}"
          jamf_package.save
        end

        # repair the package object only
        #############################
        def repair_jamf_package
          # If these values are all correct, nothing will be saved
          progress "Jamf: Repairing Package '#{jamf_pkg_name}'", log: :info
          jamf_package.packageName = jamf_pkg_name
          jamf_package.fileName = "#{jamf_pkg_name}.pkg"
          jamf_package.rebootRequired = reboot
          jamf_package.notes = jamf_package_notes
          jamf_package.categoryId = jamf_xolo_category_id
          jamf_package.osRequirements = ">=#{min_os}"
          jamf_package.save
        end

        # @return [String] the URL for the Package that installs this version in Jamf Pro
        ######################
        def jamf_package_url
          return @jamf_package_url if @jamf_package_url
          return unless jamf_pkg_id

          # @jamf_package_url = "#{jamf_gui_url}/packages.html?id=#{jamf_pkg_id}&o=r"

          @jamf_package_url = "#{jamf_gui_url}/view/settings/computer-management/packages/#{jamf_pkg_id}?tab=general"
          # https://casper.pixar.com:8443/view/settings/computer-management/packages/12042?tab=general
        end

        # Delete the package for this version from Jamf Pro.
        # Package deletion takes a long time, so we do it in a threadpool
        # and tell the admin to check the Alert Tool for completion
        # (if we have an alert tool in place) or to wait at least 5 min before
        # re-adding the same version.
        #
        # @return [void]
        #########################
        def delete_jamf_package
          pkg_id = Jamf::JPackage.valid_id packageName: jamf_pkg_name, cnx: jamf_cnx
          return unless pkg_id

          msg = "Jamf: Starting deletion of Package '#{jamf_pkg_name}' id #{jamf_pkg_id} at #{Time.now.strftime '%F %T'}"
          progress msg, log: :info

          warning = +"IMPORTANT: Package deletion is slow. If you plan to re-add this version, '#{version}', please\n  "
          warning <<
            if Xolo::Server.config.alert_tool
              'check your Xolo alerts for completion, which can take up to 5 minutes,'
            else
              'wait at least 5 minutes'
            end
          warning << ' before re-adding this version.'

          progress warning, log: nil

          self.class.pkg_deletion_pool.post do
            start = Time.now
            log_info "Jamf: Started threadpool deletion of Package '#{jamf_pkg_name}' id #{jamf_pkg_id} at #{start}"
            jamf_cnx.timeout = 3600
            Jamf::JPackage.delete pkg_id, cnx: jamf_cnx
            finish = Time.now
            duration = (finish - start).to_i.pix_humanize_secs
            log_info "Jamf: Deleted Package '#{jamf_pkg_name}' id #{jamf_pkg_id} in #{duration}", alert: true
          rescue => e
            log_error "Package Deletion thread: #{e.class}: #{e}"
            e.backtrace.each { |l| log_error "..#{l}" }
          end
        end

        #######  The Jamf Auto Install Policy
        ###########################################
        ###########################################

        # Create or fetch the auto install policy for this version
        # If we are deleting and it doesn't exist, return nil.
        #
        # @return [Jamf::Policy] The auto-install-policy for this version, if it exists
        ##########################
        def jamf_auto_install_policy
          @jamf_auto_install_policy ||=
            if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_auto_install_policy_name
              Jamf::Policy.fetch(name: jamf_auto_install_policy_name, cnx: jamf_cnx)
            else
              return if deleting?

              create_jamf_auto_install_policy
            end
        end

        # The auto install policy is triggered by checkin
        # but may have narrow scope targets, or may be
        # targeted to 'all' (after release)
        # Before release, the targets are those defined in #pilot_groups_to_use
        #
        # After release, the targets are changed to those
        # in title_object#target_group
        #
        # This policy is never in self service
        # @return [Jamf::Policy] the auto install policy for this version
        #########################
        def create_jamf_auto_install_policy
          progress "Jamf: Creating Auto Install Policy: #{jamf_auto_install_policy_name}", log: :debug
          pol = Jamf::Policy.create name: jamf_auto_install_policy_name, cnx: jamf_cnx
          configure_jamf_auto_install_policy(pol)
          pol.save
          pol
        end

        # repair the auto-install policy only
        #############################
        def repair_jamf_auto_install_policy
          progress "Jamf: Repairing Auto Install Policy '#{jamf_auto_install_policy_name}'", log: :info
          pol = jamf_auto_install_policy
          configure_jamf_auto_install_policy(pol)
          pol.save
        end

        # Configure the given policy as the auto-install policy for this version
        # @param pol [Jamf::Policy] the policy to configure
        ################################
        def configure_jamf_auto_install_policy(pol)
          pol.category = Xolo::Server::JAMF_XOLO_CATEGORY
          pol.set_trigger_event :checkin, true
          pol.set_trigger_event :custom, Xolo::BLANK
          pol.frequency = :once_per_computer
          pol.retry_event = :checkin
          pol.retry_attempts = 5
          pol.recon = true

          pol.package_names.each { |pkg_name| pol.remove_package pkg_name }
          pol.add_package jamf_pkg_name

          # exclusions are for always
          set_policy_exclusions pol

          # set the scope targets based on status
          if pilot?
            set_policy_pilot_groups pol
          else
            set_policy_release_groups pol
          end

          # enable or disable based on status
          if pilot? || released?
            pol.enable
          else
            pol.disable
          end
        end

        # @return [String] the URL for the Jamf Pro Policy that does auto-installs of this version
        ######################
        def jamf_auto_install_policy_url
          return @jamf_auto_install_policy_url if @jamf_auto_install_policy_url

          pol_id = Jamf::Policy.valid_id jamf_auto_install_policy_name, cnx: jamf_cnx
          return unless pol_id

          @jamf_auto_install_policy_url = "#{jamf_gui_url}/policies.html?id=#{pol_id}&o=r"
        end

        #######  The Jamf Manual Install Policy
        ###########################################
        ###########################################

        # Create or fetch the manual install policy for this version
        # If we are deleting and it doesn't exist, return nil.
        #
        # @return [Jamf::Policy] The manual-install-policy for this version, if it exists
        ##########################
        def jamf_manual_install_policy
          @jamf_manual_install_policy ||=
            if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_manual_install_policy_name
              Jamf::Policy.fetch(name: jamf_manual_install_policy_name, cnx: jamf_cnx)
            else
              return if deleting?

              create_jamf_manual_install_policy
            end
        end

        # The manual install policy is always scoped to all computers, with
        # exclusions
        #
        # The policy has a custom trigger, or can be installed via self service
        #
        #########################
        def create_jamf_manual_install_policy
          progress "Jamf: Creating Manual Install Policy: #{jamf_manual_install_policy_name}", log: :info

          pol = Jamf::Policy.create name: jamf_manual_install_policy_name, cnx: jamf_cnx
          configure_jamf_manual_install_policy(pol)
          pol.save
          pol
        end

        # repair the manual-install policy only
        #############################
        def repair_jamf_manual_install_policy
          pol = jamf_manual_install_policy
          progress "Jamf: Repairing Manual Install Policy '#{jamf_manual_install_policy_name}'", log: :info
          configure_jamf_manual_install_policy(pol)
          pol.save
        end

        # Configure the given policy as the manual-install policy for this version
        # @param pol [Jamf::Policy] the policy to configure
        ##########################
        def configure_jamf_manual_install_policy(pol)
          pol.category = Xolo::Server::JAMF_XOLO_CATEGORY
          pol.set_trigger_event :checkin, false
          pol.set_trigger_event :custom, jamf_manual_install_trigger
          pol.frequency = :ongoing
          pol.recon = true

          pol.package_names.each { |pkg_name| pol.remove_package pkg_name }
          pol.add_package jamf_pkg_name

          set_policy_to_all_targets pol
          set_policy_exclusions pol

          # These policies shouldn't be in ssvc
          # only the title's jamf_manual_install_released_policy is
          pol.remove_from_self_service if pol.in_self_service?
          pol.enable
        end

        # @return [String] the URL for the Jamf Pro Policy that does manual installs of this version
        ######################
        def jamf_manual_install_policy_url
          return @jamf_manual_install_policy_url if @jamf_manual_install_policy_url

          pol_id = Jamf::Policy.valid_id jamf_manual_install_policy_name, cnx: jamf_cnx
          return unless pol_id

          @jamf_manual_install_policy_url = "#{jamf_gui_url}/policies.html?id=#{pol_id}&o=r"
        end

        #######  The Jamf Installed Group
        ###########################################
        ###########################################

        # Create or fetch the smart group of macs with this version installed
        # If we are deleting and it doesn't exist, return nil
        #
        # @return [Jamf::ComputerGroup] the smart group.
        #########################
        def jamf_installed_group
          return @jamf_installed_group if @jamf_installed_group

          if Jamf::ComputerGroup.all_names(cnx: jamf_cnx).include? jamf_installed_group_name
            @jamf_installed_group = Jamf::ComputerGroup.fetch(
              name: jamf_installed_group_name,
              cnx: jamf_cnx
            )
          else
            return if deleting?

            create_jamf_installed_group

          end
          @jamf_installed_group
        end

        # Create the smart group of macs with this version installed
        #
        # @return [Jamf::ComputerGroup] the smart group.
        #########################
        def create_jamf_installed_group
          progress "Jamf: Creating smart group '#{jamf_installed_group_name}'", log: :info

          @jamf_installed_group = Jamf::ComputerGroup.create(
            name: jamf_installed_group_name,
            type: :smart,
            cnx: jamf_cnx
          )
          configure_jamf_installed_group @jamf_installed_group
          @jamf_installed_group.save
          @jamf_installed_group
        end

        # Reset the configuration of the jamf_installed_group
        #########################
        def repair_jamf_installed_group
          configure_jamf_installed_group jamf_installed_group
          jamf_installed_group.save
        end

        # Set the configuration of the given smart group
        # as needed for the jamf_installed_group
        # @param grp [Jamf::ComputerGroup] the group to configure
        #
        # @return [void]
        #########################
        def configure_jamf_installed_group(grp)
          progress "Jamf: Setting criteria for smart group '#{grp.name}'", log: :info
          grp.criteria = Jamf::Criteriable::Criteria.new(jamf_installed_group_criteria)
        end

        # The criteria for the smart group in Jamf that contains all Macs
        # with this version of this title installed
        #
        # If we have, or are about to update to, a version_script (EA) then use it,
        # otherwise use the app_name and app_bundle_id.
        #
        # @return [Array<Jamf::Criteriable::Criterion>]
        ###################################
        def jamf_installed_group_criteria
          # does this title use an app bundle?
          if title_object.app_name
            [
              Jamf::Criteriable::Criterion.new(
                and_or: :and,
                name: 'Application Title',
                search_type: 'is',
                value: title_object.app_name
              ),

              Jamf::Criteriable::Criterion.new(
                and_or: :and,
                name: 'Application Bundle ID',
                search_type: 'is',
                value: title_object.app_bundle_id
              ),

              Jamf::Criteriable::Criterion.new(
                and_or: :and,
                name: 'Application Version',
                search_type: 'is',
                value: version
              )
            ]

          # if not, it must have a version script
          elsif title_object.version_script
            [
              Jamf::Criteriable::Criterion.new(
                and_or: :and,
                name: title_object.jamf_normal_ea_name,
                search_type: 'is',
                value: version
              )
            ]

          else
            raise Xolo::Core::Exceptions::InvalidDataError, "Title #{title} has neither a version_script nor a defined app bundle."
          end
        end

        #########################
        def jamf_installed_group_url
          return @jamf_installed_group_url if @jamf_installed_group_url

          gr_id = Jamf::ComputerGroup.valid_id jamf_installed_group_name, cnx: jamf_cnx
          return unless gr_id

          @jamf_installed_group_url = "#{jamf_gui_url}/smartComputerGroups.html?id=#{gr_id}&o=r"
        end

        #######  The Jamf Auto Re-Install Policy
        ###########################################
        ###########################################

        # Create or fetch the auto re-install policy for this version
        # If we are deleting and it doesn't exist, return nil.
        #
        # @return [Jamf::Policy] The auto-install-policy for this version, if it exists
        ##########################
        def jamf_auto_reinstall_policy
          @jamf_auto_reinstall_policy ||=
            if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_auto_reinstall_policy_name
              Jamf::Policy.fetch(name: jamf_auto_reinstall_policy_name, cnx: jamf_cnx)
            else
              return if deleting?

              create_jamf_auto_reinstall_policy
            end
        end

        # The auto rionstall policy, for when a pkg is re-uploaded for this version.
        # @return [Jamf::Policy] the auto install policy for this version
        #########################
        def create_jamf_auto_reinstall_policy
          progress "Jamf: Creating Auto Re-Install Policy: #{jamf_auto_reinstall_policy_name}", log: :debug
          pol = Jamf::Policy.create name: jamf_auto_reinstall_policy_name, cnx: jamf_cnx
          configure_jamf_auto_reinstall_policy(pol)
          pol.save
          pol
        end

        # Reset the configuration of the jamf_installed_group
        #########################
        def repair_jamf_auto_reinstall_policy
          progress "Jamf: Repairing Auto Re-Install Policy: #{jamf_auto_reinstall_policy_name}", log: :debug
          configure_jamf_auto_reinstall_policy jamf_auto_reinstall_policy
        end

        # Set the proper config for the auto reinstall policy
        # @param pol [Jamf::Policy] the policy to configure
        ######################
        def configure_jamf_auto_reinstall_policy(pol)
          pol.category = Xolo::Server::JAMF_XOLO_CATEGORY
          pol.set_trigger_event :checkin, true
          pol.set_trigger_event :custom, Xolo::BLANK
          pol.frequency = :once_per_computer
          pol.retry_event = :checkin
          pol.retry_attempts = 5
          pol.scope.set_targets :computer_groups, jamf_installed_group

          # exclusions are for always
          set_policy_exclusions pol

          pol.package_names.each { |pkg_name| pol.remove_package pkg_name }
          pol.add_package jamf_pkg_name

          # NOTE: this policy is not enabled by default - it will be enabled
          # if/when the pkg for the policy is re-uploaded
          pol.enable if reupload_date.is_a? Time
        end

        # @return [String] the URL for the Jamf Pro Policy that does auto reinstalls of this version
        ######################
        def jamf_auto_reinstall_policy_url
          return @jamf_auto_reinstall_policy_url if @jamf_auto_reinstall_policy_url

          pol_id = Jamf::Policy.valid_id jamf_auto_reinstall_policy_name, cnx: jamf_cnx
          return unless pol_id

          @jamf_auto_reinstall_policy_url = "#{jamf_gui_url}/policies.html?id=#{pol_id}&o=r"
        end

        #######  The Jamf Patch Policy
        ###########################################
        ###########################################

        # Fetch or create the patch policy for this version
        # If we are deleting and it doesn't exist, return nil.
        # @return [Jamf::PatchPolicy, nil] The patch policy for this version, if it exists
        ##########################
        def jamf_patch_policy
          @jamf_patch_policy ||=
            if Jamf::PatchPolicy.all_names(cnx: jamf_cnx).include? jamf_patch_policy_name
              Jamf::PatchPolicy.fetch(name: jamf_patch_policy_name, cnx: jamf_cnx)
            else
              return if deleting?

              create_jamf_patch_policy
            end
        end

        # @return [Jamf::PatchPolicy] The xolo patch policy for this version
        #########################
        def create_jamf_patch_policy
          progress "Jamf: Creating Patch Policy for Version '#{version}' of Title '#{title}'.", log: :info

          # TODO: decide how many patch policies - see comments at top
          # Probably one: for pilots initially and then rescoped to all for release
          #
          # TODO: How to set these, and should they be settable
          # at the Xolo::Title or  Xolo::Version level?
          #
          # allow downgrade? No, to start with.
          # When a version is released, IF we are rolling back, then this will be set.
          # This is to be set only on the current release and only when it was a rollback.
          #
          # patch_unknown_versions... yes?
          #
          # if not in ssvc:
          # - grace period?
          # - update warning Message and Subject
          #
          # if in ssvc:
          # - any way to use existing icon?
          # - use title desc... do we want a version desc??
          # - notifications?  Message and Subject? SSvc only, Notif Ctr?
          # - deadline and grace period message and subbject

          ppol = Jamf::PatchPolicy.create(
            cnx: jamf_cnx,
            name: jamf_patch_policy_name,
            patch_title: title_object.jamf_patch_title.id,
            target_version: version
          )

          # when first creating a patch policy, its status is always
          # 'pilot' so the scope targets are the pilot groups, if any.
          # When the version is released, the patch policy will be
          # rescoped to all targets (limited by eligibility)
          set_policy_pilot_groups ppol

          # exclusions are for always
          set_policy_exclusions ppol

          ppol.allow_downgrade = false

          ppol.patch_unknown = true

          ppol.enable

          ppol.save

          ppol
        end

        # repair the patch policy only
        #############################
        def repair_jamf_patch_policy
          progress "Jamf: Repairing Patch Policy '#{jamf_patch_policy_name}'", log: :info
          assign_pkg_to_patch_in_jamf

          ppol = jamf_patch_policy
          ppol.name = jamf_patch_policy_name
          ppol.target_version = version

          if pilot?
            set_policy_pilot_groups ppol
          else
            ppol.scope.set_all_targets
          end

          # exclusions are for always
          set_policy_exclusions ppol

          if pilot? || released?
            ppol.enable
          else
            ppol.disable
          end

          ppol.save
        end

        # @return [String] the URL for the Jamf Pro Patch Policy that updates to this version
        ######################
        def jamf_patch_policy_url
          return @jamf_patch_policy_url if @jamf_patch_policy_url

          title_id = title_object.jamf_patch_title_id

          pol_id = Jamf::PatchPolicy.valid_id jamf_patch_policy_name, cnx: jamf_cnx
          return unless pol_id

          @jamf_manual_install_policy_url = "#{jamf_gui_url}/patchDeployment.html?softwareTitleId=#{title_id}&id=#{pol_id}&o=r"
        end

        ################
        #
        #
        #
        #
        #
        #
        #
        #
        #
        ################

        # set target groups in a pilot [patch] policy object's scope
        # REMEMBER TO SAVE THE POLICY LATER
        #
        # @param pol [Jamf::Policy, Jamf::PatchPolicy]
        # @return [void]
        ############################
        def set_policy_pilot_groups(pol)
          pilots = pilot_groups_to_use
          pilots ||= []
          log_debug "Jamf: setting pilot scope targets for #{pol.class} '#{pol.name}' to: #{pilots.join ', '}"

          pol.scope.set_targets :computer_groups, pilots
        end

        # Set a policy to be scoped to all targets
        # REMEMBER TO SAVE THE POLICY LATER
        #
        # @param pol [Jamf::Policy, Jamf::PatchPolicy]
        # @return [void]
        ############################
        def set_policy_to_all_targets(pol)
          log_debug "Jamf: setting scope target for #{pol.class} '#{pol.name}' to all computers"
          pol.scope.set_all_targets
        end

        # set target groups in a non=pilot [patch] policy object's scope
        # REMEMBER TO SAVE THE POLICY LATER
        #
        # @param pol [Jamf::Policy, Jamf::PatchPolicy]
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        # @return [void]
        ############################
        def set_policy_release_groups(pol, ttl_obj: nil)
          ttl_obj ||= title_object
          targets = release_groups_to_use(ttl_obj: ttl_obj) || []

          log_debug "Jamf: setting release scope targets for #{pol.class} '#{pol.name}' to: #{targets.join ', '}"

          if targets.include? Xolo::TARGET_ALL
            pol.scope.set_all_targets
          else
            pol.scope.set_targets :computer_groups, targets
          end
        end

        # set excluded groups in a [patch] policy object's scope
        # REMEMBER TO SAVE THE POLICY LATER
        #
        # This applies more nuance to the 'excluded_groups_to_use' depending on
        # the policy in question. E.g. manual-install policy should not
        # have the installed-group excluded, to allow re-installs
        #
        # @param pol [Jamf::Policy, Jamf::PatchPolicy]
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        ############################
        def set_policy_exclusions(pol, ttl_obj: nil)
          ttl_obj ||= title_object
          # dup, so when we add the installed group below, we don't
          # keep that for future calls to this method.
          exclusions = excluded_groups_to_use(ttl_obj: ttl_obj).dup
          exclusions ||= []

          # the initial auto-install policies must also exclude any mac with the title
          # already installed
          # But the manual install policy should never exclude it - so that
          # one-off macs can install or re-install at any time.
          if pol.is_a?(Jamf::Policy) && pol.name == jamf_auto_install_policy_name
            # calling ttl_obj.jamf_installed_group will create the group if needed
            exclusions << ttl_obj.jamf_installed_group.name
          end

          log_debug "Jamf: updating exclusions for #{pol.class} '#{pol.name}' to: #{exclusions.join ', '}"

          exclusions.uniq!
          pol.scope.set_exclusions :computer_groups, exclusions
        end

        # @return [Jamf::PatchTitle::Version] The Jamf::PatchTitle::Version for this
        # Xolo version
        #####################
        def jamf_patch_version
          return @jamf_patch_version if @jamf_patch_version

          # NOTE: in the line below, use the title_object's call to #jamf_patch_title
          # because that will cache the Jamf::PatchTitle instance, and we need to
          # use it to save changes to its Versions.
          # Using the class method won't cache the instance we will need in the
          # future.
          @jamf_patch_version = title_object.jamf_patch_title.versions[version]
          return @jamf_patch_version if @jamf_patch_version

          # TODO: wait for it to appear when adding?
          msg = "Jamf: Version '#{version}' of Title '#{title}' is not visible in Jamf. Is the Patch enabled in the Title Editor?"
          log_error msg
          raise Xolo::NoSuchItemError, msg
        end

        # Wait until the version is visible from the title editor
        # then assign the pkg to it in Jamf Patch,
        # and create the patch policy.
        #
        # Do this in a thread so the xadm user doesn't wait up to ?? minutes.
        #
        # @return [void]
        #########################
        def activate_patch_version_in_jamf
          # don't do this if there's already one running for this instance
          if @activate_patch_version_thread&.alive?
            log_debug "Jamf: activate_patch_version_thread already running. Caller: #{caller_locations.first}"
            return
          end

          msg = "Jamf: Will assign Jamf pkg '#{jamf_pkg_name}' and create the patch policy when this version becomes visible to Jamf Pro from the Title Editor."
          progress msg, log: :debug

          @activate_patch_version_thread = Thread.new do
            log_debug "Jamf: Starting activate_patch_version_thread waiting for version #{version} of title #{title} to become visible from the title editor"

            start_time = Time.now
            max_time = start_time + Xolo::Server::MAX_JAMF_WAIT_FOR_TITLE_EDITOR
            start_time = start_time.strftime '%F %T'

            did_it = false

            while Time.now < max_time
              sleep 15
              log_debug "Jamf: checking for version #{version} of title #{title} to become visible from the title editor since #{start_time}"

              # check for the existence of the jamf_patch_title every time, since it might have gone away
              # if the title was deleted while this was happening.
              next unless title_object.jamf_patch_title(refresh: true) && title_object.jamf_patch_title.versions.key?(version)

              did_it = true
              break
            end

            if did_it
              assign_pkg_to_patch_in_jamf
              # give jamf a moment to catch up and refresh the patch title
              # so we see the pkg has been assigned
              sleep 2
              title_object.jamf_patch_title(refresh: true)

              create_jamf_patch_policy
              msg = "Jamf: Version '#{version}' of title '#{title}' is now visible in Jamf Pro. Package assigned and Patch policy created."
              log_info msg, alert: true
            else
              msg = "Jamf: ERROR: Version '#{version}' of title '#{title}' has not become visible from the Title Editor in over #{Xolo::Server::MAX_JAMF_WAIT_FOR_TITLE_EDITOR} seconds. The package has not been assigned, and no patch policy was created."
              log_error msg, alert: true
            end
          end # thread
          @activate_patch_version_thread.name = "activate_patch_version_thread-#{title}-#{version}"
        end

        # Assign the Package to the Jamf::PatchTitle::Version for this Xolo version.
        # This 'activates' the version in Jamf Patch, and must happen before
        # patch policies can be created
        #
        # Jamf::PatchTitle::Version objects are contained in the matching
        # Jamf::PatchTitle, and to make or save changes, we have to fetch the title,
        # update the version, and save the title.
        #
        # NOTE: This can't happen until Jamf see's the version in the title editor
        # otherwise you'll get an error. The methods that call this should ensure
        # the version is visible.
        #
        # @return [void]
        ########################################
        def assign_pkg_to_patch_in_jamf
          log_info "Jamf: Assigning package '#{jamf_pkg_name}' to patch version '#{version}' of title '#{title}'"

          jamf_patch_version.package = jamf_pkg_name
          title_object.jamf_patch_title.save
        end

        # Validate and fix any Jamf::JPackage objects that
        # related to this version:
        # - the package object
        # - the installed-group
        # - the auto-install policy
        # - the manual-install policy
        # - the auto-reinstall policy
        # - the patch policy
        #########################################
        def repair_jamf_version_objects
          repair_jamf_package
          repair_jamf_installed_group
          repair_jamf_auto_install_policy
          repair_jamf_manual_install_policy
          repair_jamf_auto_reinstall_policy
          repair_jamf_patch_policy
        end

        # Disable the auto-install and patch policies for this version when it
        # is deprecated or skipped
        #
        # Leave the manual install policy active, but remove it from self-service
        #
        # @param reason [Symbol] :deprecated or :skipped
        #
        # @return [void]
        #########################
        def disable_policies_for_deprecation_or_skipping(reason)
          progress "Jamf: Disabling auto-install policy for #{reason} version '#{version}'"
          pol = jamf_auto_install_policy
          pol.disable
          pol.save

          progress "Jamf: Disabling patch policy for #{reason} version '#{version}'"
          ppol = jamf_patch_policy
          ppol.disable
          # ensure patch policy is NOT set to 'allow downgrade'
          ppol.allow_downgrade = false
          ppol.save
        end

        # reset all the policies for this version to pilot
        #
        # @return [void]
        ######################
        def reset_policies_to_pilot
          # set scope targets of auto-install policy to pilot-groups and re-enable
          msg = "Jamf: Version '#{version}': Setting scope targets of auto-install policy to pilot_groups: #{pilot_groups_to_use.join(', ')}"
          progress msg, log: :info

          jamf_auto_install_policy.scope.set_targets :computer_groups, pilot_groups_to_use
          jamf_auto_install_policy.enable
          jamf_auto_install_policy.save

          msg = "Jamf: Version '#{version}': Setting scope targets of patch policy to pilot_groups"
          progress msg, log: :info

          # set scope targets of patch policy to pilot-groups and re-enable
          jamf_patch_policy.scope.set_targets :computer_groups, pilot_groups_to_use
          # ensure patch policy is NOT set to 'allow downgrade'
          jamf_patch_policy.allow_downgrade = false
          jamf_patch_policy.enable
          jamf_patch_policy.save
        end

        # Update all the pilot_groups policy scopes for this version when
        # either the title or version has changed them
        #
        # Nothing to do if the version isn't currently in :pilot status
        #
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        #########################
        def update_pilot_groups
          # nothing unless we're in pilot
          return unless status == Xolo::Server::Version::STATUS_PILOT

          # - no changes to the manual install policy: scope-target is all

          # - update the auto install policy
          progress "Jamf: Updating pilot groups for Auto Install Policy '#{jamf_auto_install_policy_name}'."

          pol = jamf_auto_install_policy

          set_policy_pilot_groups(pol)
          pol.save

          # - update the patch policy
          progress "Jamf: Updating pilot groups for Patch Policy '#{jamf_patch_policy_name}'."

          pol = jamf_patch_policy

          set_policy_pilot_groups(pol)
          pol.save
        end

        # Update all the release_groups policy scopes for this version when
        # either the title or version has changed them
        #
        # Nothing to do if the version is currently in pending or pilot status
        #
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        #########################
        def update_release_groups(ttl_obj: nil)
          return unless status == Xolo::Server::Version::STATUS_RELEASED

          # - no changes to the manual install policy: scope-target is all

          # - update the auto-install policy
          pol = jamf_auto_install_policy
          return unless pol

          set_policy_release_groups(pol, ttl_obj: ttl_obj)
          pol.save
          progress "Jamf: updated release groups for Auto Install Policy '#{jamf_auto_install_policy_name}'.",
                   log: :info

          # - no changes to the patch policy: scope-target is all once released
        end

        # Update all the excluded_groups policy scopes for this version when
        # either the title or version has changed them
        #
        # Applies regardless of status
        #
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        #########################
        def update_excluded_groups(ttl_obj: nil)
          log_debug "Updating Excluded Groups for Version '#{version}' of Title '#{title}'"

          # - update the manual install policy
          pol = jamf_manual_install_policy
          if pol
            progress "Jamf: Updating excluded groups for Manual Install Policy '#{jamf_auto_install_policy_name}'."
            set_policy_exclusions(pol, ttl_obj: ttl_obj)
            pol.save
          end

          # - update the auto install policy
          pol = jamf_auto_install_policy
          if pol
            progress "Jamf: Updating excluded groups for Auto Install Policy '#{jamf_auto_install_policy_name}'."
            set_policy_exclusions(pol, ttl_obj: ttl_obj)
            pol.save
          end
          # - update the patch policy

          pol = jamf_patch_policy
          return unless pol

          progress "Jamf: Updating exccluded groups for Patch Policy '#{jamf_patch_policy_name}'."
          set_policy_exclusions(pol, ttl_obj: ttl_obj)
          pol.save
        end

        # Install this version on a one or more computers via MDM.
        #
        # @param targets [Hash ] With the following keys
        #   - computers: [Array<String, Integer>] The computer identifiers to install on.
        #     Identifiers are either serial numbers, names, or Jamf IDs.
        #   - groups: [Array<String, Integer>] The names or ids of computer groups to install on.
        #
        # @return [Hash] The results of the install with the following keys
        #   - removals: [Array<Hash>] { device: <String>, group: <InteStringger>, reason: <String> }
        #   - queuedCommands: [Array<Hash>] { device: <String>, commandUuid: <String> }
        #   - errors: [Array<Hash>] { device: <String>, group: <Integer>, reason: <String> }
        #
        def deploy_via_mdm(targets)
          unless dist_pkg
            raise Xolo::UnsupportedError,
                  'MDM deployment is not supported for this version, it is not a Distribution Package.'
          end

          all_targets = targets[:computers] || []
          removals = []

          # expand groups into computers,
          all_targets += expand_groups_for_deploy(targets[:groups], removals) if targets[:groups]

          # remove duplicates
          all_targets.uniq!

          # remove invalid computers, after this all_targets will be valid computer ids
          remove_invalid_computers_for_deploy(all_targets, removals)

          # remove members of excluded groups from the list of targets
          remove_exclusions_from_deploy(all_targets, removals)

          if all_targets.empty?
            log_info "Jamf: No valid computers to deploy to for version '#{version}' of title '#{title}'."
            queued_cmds = []
            deploy_errs = []

          else
            # deploy the package to the computers
            jamf_package.deploy_via_mdm computer_ids: all_targets
            # convert ids to names for the response
            comp_ids_to_names = Jamf::Computer.map_all(:id, to: :name, cnx: jamf_cnx)

            queued_cmds = jamf_package.deploy_response[:queuedCommands].map do |qc|
              { device: comp_ids_to_names[qc[:device]], commandUuid: qc[:commandUuid] }
            end

            deploy_errs = jamf_package.deploy_response[:errors].map do |err|
              { device: comp_ids_to_names[err[:device]], reason: err[:reason] }
            end

            log_info "Jamf: Deployed version '#{version}' of title '#{title}' to #{all_targets.size} computers via MDM"

          end

          removals.each { |r| log_info "Jamf: Removal #{r}" }
          queued_cmds.each { |qc| log_info "Jamf: Queued Command #{qc}" }
          deploy_errs.each { |err| log_info "Jamf: Error #{err}" }

          {
            removals: removals,
            queuedCommands: queued_cmds,
            errors: deploy_errs
          }
        end

        # expand computer groups given for deploy_via_mdm
        #
        # @param groups [Array<String, Integer>] The names or ids of computer groups to install on.
        # @param removals [Array<Hash>] The groups that are not valid, for reporting back to the caller
        #
        # @return [Array<Integer>] The ids of the computers in the groups
        #########################
        def expand_groups_for_deploy(groups, removals)
          log_debug "Expanding group targets for MDM deployment of title '#{title}',  version '#{version}'"

          computers = []
          groups.each do |g|
            gid = Jamf::ComputerGroup.valid_id g, cnx: jamf_cnx
            if gid
              jgroup = Jamf::ComputerGroup.fetch id: gid, cnx: jamf_cnx

              if excluded_groups_to_use.include? jgroup.name
                log_debug "Jamf: Group '#{jgroup.name}' is in the excluded groups list. Removing."
                removals << { device: nil, group: g, reason: "Group '#{jgroup.name}' is in the excluded groups list" }
                next
              end
              log_debug "Jamf: Adding computers from group '#{jgroup.name}' to deployment targets"
              computers += jgroup.member_ids
            else
              log_debug "Jamf: Group '#{g}' not found in Jamf Pro. Removing."
              removals << { device: nil, group: g, reason: 'Group not found in Jamf Pro' }
            end
          end
          computers
        end

        # remove invalid computers from the list of targets for deploy_via_mdm
        #
        # @param targets [Array<String, Integer>] The names or ids of computers to install on.
        # @param removals [Array<Hash>] The computers that are not valid, for reporting back to the caller
        #
        # @return [void]
        #########################
        def remove_invalid_computers_for_deploy(targets, removals)
          log_debug "Removing invalid computer targets for MDM deployment of title '#{title}',  version '#{version}'"

          targets.map! do |c|
            id = Jamf::Computer.valid_id c, cnx: jamf_cnx
            if id
              id
            else
              removals << { device: c, group: nil, reason: 'Computer not found in Jamf Pro' }
              nil
            end
          end.compact!
        end

        # Remove exclusions from the list of targets for deploy_via_mdm
        #
        # @param targets [Array<Integer>] The ids of computers to install on.
        # @param removals [Array<Hash>] The computers that are not valid, for reporting back to the caller
        #
        # @return [void]
        #########################
        def remove_exclusions_from_deploy(targets, removals)
          log_debug "Removing excluded computer targets for MDM deployment of title '#{title}',  version '#{version}'"

          excluded_groups_to_use.each do |group|
            gid = Jamf::ComputerGroup.valid_id group, cnx: jamf_cnx
            unless gid
              log_error "Jamf: Excluded group '#{group}' not found in Jamf Pro. Skipping."
              next
            end # unless gid

            jgroup = Jamf::ComputerGroup.fetch id: gid, cnx: jamf_cnx
            jgroup.members.each do |member|
              next unless targets.include? member[:id]

              log_debug "Jamf: Removing computer '#{member[:name]}' (#{member[:id]}) from deployment targets because it is in excluded group '#{group}'"
              targets.delete member[:id]
              removals << { device: member[:name], group: nil, reason: "In excluded group '#{group}'" }
            end
          end # excluded_groups_to_use.each
        end

        # Get the patch report for this version
        # @return [Arrah<Hash>] Data for each computer with this version of this title installed
        ######################
        def patch_report
          title_object.patch_report vers: version
        end

        # @return [String] The start of the Jamf Pro URL for GUI/WebApp access
        ################
        def jamf_gui_url
          @jamf_gui_url ||= title_object.jamf_gui_url
        end

        # This will start a thread
        # that will wait some period of time (to allow for pkg uploads
        # to complete) before enabling and flushing the logs for the reinstall policy.
        # This will make all macs with this version installed get it re-installed.
        # @return [void]
        def wait_to_enable_reinstall_policy
          # TODO: some setting to determine how long to wait?
          # - If uploading via the Jamf API, we need to give it time
          #   to then upload the file to the cloud distribution point
          # - If uploading via a custom tool, we need to give that
          #   tool time to re-upload to wherever it uploads to
          # - May need to wait for other non-jamf/non-xolo processes
          #   to sync the package to other distribution points. This
          #   might be very site-specific.

          # For now, we wait 15 minutes.
          wait_time = 15 * 60

          @enable_reinstall_policy_thread = Thread.new do
            log_debug "Jamf: Starting enable_reinstall_policy_thread: waiting #{wait_time} seconds before enabling reinstall policy for version #{version} of title #{title}"
            sleep wait_time

            log_debug "Jamf: enable_reinstall_policy_thread: enabling and flushing logs for reinstall policy for version #{version} of title #{title}"

            pol = jamf_auto_reinstall_policy
            pol.enable
            pol.flush_logs
            pol.save
          end
          @enable_reinstall_policy_thread.name = "enable_reinstall_policy_thread-#{title}-#{version}"
        end

      end # VersionJamfAccess

    end # Mixins

  end # Server

end # module Xolo
