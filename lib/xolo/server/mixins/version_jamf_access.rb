# Copyright 2024 Pixar
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

        # The policy that does initial installs on-demand
        # (via 'xolo install <title> <version') is named the full
        # prefix plus this suffix.
        JAMF_POLICY_NAME_MANUAL_INSTALL_SFX = '-manual-install'

        # The policy that does auto-installs is named the full
        # prefix plus this suffix.
        # The scope is changed as needed when a version's status
        # changes
        JAMF_POLICY_NAME_AUTO_INSTALL_SFX = '-auto-install'

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
        # Since there is one per title, it's name is stored in the title object's #jamf_installed_smart_group_name
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

        # Create everything we need in Jamf
        ############################
        def create_in_jamf
          ensure_jamf_xolo_category

          # this will create or fetch the pkg
          jamf_package

          # these will create or fetch the policies
          jamf_auto_install_policy
          jamf_manual_install_policy

          title_object.activate_patch_title_in_jamf

          activate_patch_version_in_jamf
        end

        # ensure the xolo category exists
        ##############################
        def ensure_jamf_xolo_category
          return if Jamf::Category.all_names(cnx: jamf_cnx).include? Xolo::Server::JAMF_XOLO_CATEGORY

          log_debug "Jamf Pro: Creating category #{Xolo::Server::JAMF_XOLO_CATEGORY}"
          Jamf::Category.create(name: Xolo::Server::JAMF_XOLO_CATEGORY, cnx: jamf_cnx).save
        end

        # Create the Jamf::Package object for this version if needed
        #########################
        def create_pkg_in_jamf
          pkg = Jamf::Package.create(
            cnx: jamf_cnx,
            name: jamf_pkg_name,
            filename: jamf_pkg_file,
            reboot_required: reboot,
            notes: jamf_pkg_notes
          )
          pkg.category = Xolo::Server::JAMF_XOLO_CATEGORY

          # TODO: Implement max_os, either here, or by maintaining a smart group?
          # I really which jamf would improve how package objects handle
          # OS requirements, building in the concept of min/max
          pkg.os_requirements = ">=#{min_os}"

          @jamf_pkg_id = pkg.save
          progress "Jamf: Created Package object '#{jamf_pkg_name}'", log: :info
          pkg
        rescue StandardError => e
          msg = "Jamf: Failed to create Jamf::Package '#{jamf_pkg_name}': #{e.class}: #{e}"
          log_error msg
          halt 400, msg
        end

        # @return [String] the 'notes' text for the Jamf::Package object for this version
        #############################
        def jamf_pkg_notes
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

        # Add the manual install policy to self service
        # This should only happen when a version is released.
        #
        # @return [void]
        ############################
        def add_to_self_service
          return unless title_object.self_service

          pol = jamf_manual_install_policy
          return unless pol
          return if pol.in_self_service?

          msg = "Jamf: Version '#{version}': Setting manual-install policy to appear in self-service"
          progress msg, log: :info
          pol.add_to_self_service
          pol.self_service_categories.each { |cat| pol.remove_self_service_category cat }
          pol.add_self_service_category title_object.self_service_category
          pol.self_service_description = title_object.description
          pol.self_service_display_name = title_object.display_name
          pol.self_service_install_button_text = 'Install'

          # if the policy already is using the correct icon, we're done
          return if title_object.ssvc_icon_id && pol.icon.id == title_object.ssvc_icon_id

          # an icon has been uploaded to xolo for this title
          if title_object.ssvc_icon_file

            # the icon has been uploaded to jamf, we have its id and its valid
            if title_object.ssvc_icon_id && valid_icon_id?(title_object.ssvc_icon_id)
              progress "Jamf: Version '#{version}': Attaching Self Service icon to policy", log: :info
              pol.icon = title_object.ssvc_icon_id
              need_to_upload_icon_to_jamf = false
            else
              need_to_upload_icon_to_jamf = true
            end

          # no icon has been uploaded to xolo for this title
          else
            progress "Jamf: Version '#{version}': NOTE: no Self Service icon has been uploaded to Xolo for this title."
            need_to_upload_icon_to_jamf = false
          end

          pol.save
          upload_icon_to_jamf(pol) if need_to_upload_icon_to_jamf
        end

        # upload an icon to jamf
        # @param pol [Jamf::Policy] The policy to upload the icon to
        # @return [void]
        ############################
        def upload_icon_to_jamf(pol)
          progress "Jamf: Version '#{version}': Uploading Self Service icon to Jamf", log: :info
          pol.upload :icon, title_object.ssvc_icon_file
          # a moment for jamf to catch up and assign the icon id
          sleep 2

          # update the title object with the icon id we just uploaded
          if title_object.locked?
            need_to_unlock_title = false
          else
            title_object.lock
            need_to_unlock_title = true
          end

          icon_id = Jamf::Policy.fetch(name: jamf_manual_install_policy_name, cnx: jamf_cnx).icon.id
          title_object.ssvc_icon_id = icon_id
          title_object.save_local_data
        ensure
          title_object.unlock if need_to_unlock_title
        end

        # Confirm that an icon's id is valid, if not, we'll re-upload it
        #
        # @param icon_id [String, Integer] The id of the icon to check
        #
        # @return [Boolean] true if the icon is valid, false if it's not
        ############################
        def valid_icon_id?(icon_id)
          jamf_cnx.jp_get "v1/icon/#{icon_id}"
          true
        rescue Jamf::Connection::JamfProAPIError
          false
        end

        # set target groups in a pilot [patch] policy object's scope
        # REMEMBER TO SAVE THE POLICY LATER
        #
        # @param pol [Jamf::Policy]
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        ############################
        def set_policy_pilot_groups(pol)
          pilots = pilot_groups_to_use
          pilots ||= []
          log_debug "Jamf: updating pilot scope targets for #{pol.class} '#{pol.name}' to: #{pilots.join ', '}"

          pol.scope.set_targets :computer_groups, pilots
        end

        # Set a policy to be scoped to all targets
        # REMEMBER TO SAVE THE POLICY LATER
        ############################
        def set_policy_to_all_targets(pol)
          log_debug "Jamf: updating scope target for #{pol.class} '#{pol.name}' to all computers"
          pol.scope.set_all_targets
        end

        # set target groups in a non=pilot [patch] policy object's scope
        # REMEMBER TO SAVE THE POLICY LATER
        #
        # @param pol [Jamf::Policy]
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        ############################
        def set_policy_release_groups(pol, ttl_obj: nil)
          ttl_obj ||= title_object
          targets = release_groups_to_use(ttl_obj: ttl_obj) || []

          log_debug "Jamf: updating release scope targets for #{pol.class} '#{pol.name}' to: #{targets.join ', '}"

          pol.scope.set_targets :computer_groups, targets
        end

        # set excluded groups in a [patch] policy object's scope
        # REMEMBER TO SAVE THE POLICY LATER
        # @param pol [Jamf::Policy]
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        ############################
        def set_policy_exclusions(pol, ttl_obj: nil)
          ttl_obj ||= title_object
          exclusions = excluded_groups_to_use(ttl_obj: ttl_obj)
          exclusions ||= []

          # the initial-install policies must also exclude any mac with the title
          # already installed
          if pol.is_a?(Jamf::Policy) && !exclusions.include?(ttl_obj.jamf_installed_smart_group_name)
            exclusions = exclusions.dup
            exclusions << ttl_obj.jamf_installed_smart_group_name
            log_debug "Jamf: excluding computers with the title installed from the initial-install policy '#{pol.name}'"
          end

          log_debug "Jamf: updating exclusions for #{pol.class} '#{pol.name}' to: #{exclusions.join ', '}"

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
            max_time = start_time + 3600
            start_time = start_time.strftime '%F %T'
            did_it = false

            while Time.now < max_time
              sleep 30
              log_debug "Jamf: checking for version #{version} of title #{title} to become visible from the title editor since #{start_time}"

              # check for the existence of the jamf_patch_title every time, since it might have gone away
              # if the title was deleted while this was happening.
              unless title_object.jamf_patch_title(refresh: true) && title_object.jamf_patch_title.versions.key?(version)
                next
              end

              did_it = true
              break
            end

            if did_it
              assign_pkg_to_patch_in_jamf
              create_patch_policy_in_jamf
            else
              log_error "Jamf: Expected to (re)accept version-script ExtensionAttribute '#{ted_ea_key}', but Jamf hasn't seen the change in over an hour. Please investigate.",
                        alert: true
            end
          end # thread
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
          log_debug "Jamf: Assigning package '#{jamf_pkg_name}' to patch version '#{version}' of title '#{title}'"

          jamf_patch_version.package = jamf_pkg_name
          title_object.jamf_patch_title.save
        end

        # @return [Jamf::Policy] The manual-install-policy for this version, if it exists
        ##########################
        def jamf_manual_install_policy
          @jamf_manual_install_policy ||=
            if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_manual_install_policy_name
              Jamf::Policy.fetch(name: jamf_manual_install_policy_name, cnx: jamf_cnx)
            else
              create_manual_install_policy_in_jamf
            end
        end

        # The manual install policy is always scoped to all computers, with
        # exclusions
        #
        # The policy has a custom trigger, or can be installed via self service
        #
        #########################
        def create_manual_install_policy_in_jamf
          pol = Jamf::Policy.create name: jamf_manual_install_policy_name, cnx: jamf_cnx

          pol.category = Xolo::Server::JAMF_XOLO_CATEGORY
          pol.add_package jamf_pkg_name
          pol.set_trigger_event :checkin, false
          pol.set_trigger_event :custom, jamf_manual_install_trigger

          # manual install policy is always available manually install
          # anywhere except the exclusions.
          set_policy_to_all_targets(pol)

          # exclusions are for always
          set_policy_exclusions pol

          pol.enable
          pol.save
          progress "Jamf: Created Jamf Manual Install Policy: #{jamf_manual_install_policy_name}", log: :info

          pol
        end

        # @return [Jamf::Policy] The auto-install-policy for this version, if it exists
        ##########################
        def jamf_auto_install_policy
          @jamf_auto_install_policy ||=
            if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_auto_install_policy_name
              Jamf::Policy.fetch(name: jamf_auto_install_policy_name, cnx: jamf_cnx)
            else
              create_auto_install_policy_in_jamf
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
        def create_auto_install_policy_in_jamf
          pol = Jamf::Policy.create name: jamf_auto_install_policy_name, cnx: jamf_cnx

          pol.category = Xolo::Server::JAMF_XOLO_CATEGORY
          pol.add_package jamf_pkg_name
          pol.set_trigger_event :checkin, true
          pol.set_trigger_event :custom, Xolo::BLANK

          # while in pilot, only pilot groups are targets
          set_policy_pilot_groups pol

          # exclusions are for always
          set_policy_exclusions pol

          pol.enable
          pol.save
          progress "Jamf: Created Jamf Auto Install Policy: #{jamf_auto_install_policy_name}", log: :debug
          pol
        end

        # @return [Jamf::PatchPolicy] The auto-install-policy for this version, if it exists
        ##########################
        def jamf_patch_policy
          @jamf_patch_policy ||=
            if Jamf::PatchPolicy.all_names(cnx: jamf_cnx).include? jamf_patch_policy_name
              Jamf::PatchPolicy.fetch(name: jamf_patch_policy_name, cnx: jamf_cnx)
            else
              create_patch_policy_in_jamf
            end
        end

        # @return [Jamf::PatchPolicy] The xolo patch policy for this version
        #########################
        def create_patch_policy_in_jamf
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
            target_version: version,
            patch_unknown: true
          )

          # when first creating a patch policy, its status is always
          # 'pilot' so the scope targets are the pilot groups, if any.
          # When the version is released, the patch policy will be
          # rescoped to all targets (limited by eligibility)
          ppol.scope.set_targets :computer_groups, pilot_groups_to_use

          # exclusions are for always
          set_policy_exclusions ppol

          ppol.allow_downgrade = false

          ppol.enable

          ppol.save
          progress "Jamf: Created Pilot Patch Policy for Version '#{version}' of Title '#{title}'.", log: :info

          ppol
        end

        # Apply edits to the Xolo version to Jamf as needed
        # This includes scope changes in policies, changes to pkg 'reboot' setting
        # and changes to pkg 'os_requirements'
        # Uploading a new .pkg installer happen separately
        #########################################
        def update_version_in_jamf
          unless new_data_for_update[:pilot_groups] && new_data_for_update[:pilot_groups].sort == pilot_groups.sort
            # pilots
            update_pilot_groups
          end

          unless new_data_for_update[:release_groups] && new_data_for_update[:release_groups].sort == release_groups.sort
            # release
            update_release_groups ttl_obj: title_object
          end

          unless new_data_for_update[:excluded_groups] && new_data_for_update[:excluded_groups].sort == excluded_groups.sort
            # excludes
            update_excluded_groups ttl_obj: title_object
          end

          unless new_data_for_update[:reboot] == reboot
            # reboot
            update_jamf_pkg_reboot
          end

          return if new_data_for_update[:min_os] == min_os

          update_jamf_pkg_min_os
        end

        # update the reboot setting for the Jamf::Package
        # @return [void]
        ##########################
        def update_jamf_pkg_reboot
          pkg = jamf_package
          unless pkg
            progress(
              "ERROR: Jamf: No package object defined in for version '#{version}' of title '#{title}'.",
              log: :error
            )
            return
          end
          pkg.reboot_required = reboot
          pkg.save
          progress "Jamf: Updated reboot setting for Jamf::Package '#{jamf_pkg_name}'", log: :debug
        end

        # update the min_os setting for the Jamf::Package
        # @return [void]
        ##########################
        def update_jamf_pkg_min_os
          pkg = jamf_package
          unless pkg
            progress(
              "ERROR: Jamf: No package object defined in for version '#{version}' of title '#{title}'.",
              log: :error
            )
            return
          end
          pkg.os_requirements = ">=#{min_os}"
          pkg.save
          progress "Jamf: Updated os_requirement for Jamf::Package '#{jamf_pkg_name}'", log: :debug
        end

        # TODO: handle missing pkg in jamf
        # @return [Jamf::Package] the Package object associated with this version
        ######################
        def jamf_package
          @jamf_package ||=
            if Jamf::Package.all_names(cnx: jamf_cnx).include? jamf_pkg_name
              Jamf::Package.fetch name: jamf_pkg_name, cnx: jamf_cnx
            else
              create_pkg_in_jamf
            end
        end

        # Update the SSvc Icon for the policies used by this version
        #
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        #
        # @return [void]
        ###############################
        def update_ssvc_icon(ttl_obj: nil)
          ttl_obj ||= title_object
          # update manual install policy

          log_debug "Jamf: Updating SSvc Icon for Manual Install Policy '#{jamf_manual_install_policy_name}'"
          pol = jamf_manual_install_policy
          return unless pol

          pol.upload :icon, ttl_obj.ssvc_icon_file
          progress "Jamf: Updated Icon for Manual Install Policy '#{jamf_manual_install_policy_name}'",
                   log: :debug

          # TODO: When we figure out if we want patch policies to use
          # ssvc - they will need to be updated also
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
          pol = jamf_auto_install_policy
          if pol
            set_policy_pilot_groups(pol)
            pol.save
            progress "Jamf: updated pilot groups for Auto Install Policy '#{jamf_auto_install_policy_name}'."
          end

          # - update the patch policy
          pol = jamf_patch_policy
          return unless pol

          set_policy_pilot_groups(pol)
          pol.save
          progress "Jamf: updated pilot groups for Patch Policy '#{jamf_patch_policy_name}'."
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
            set_policy_exclusions(pol, ttl_obj: ttl_obj)
            pol.save
            progress "Jamf: updated excluded groups for Manual Install Policy '#{jamf_auto_install_policy_name}'."
          end

          # - update the auto install policy
          pol = jamf_auto_install_policy
          if pol
            set_policy_exclusions(pol, ttl_obj: ttl_obj)
            pol.save
            progress "Jamf: updated excluded groups for Auto Install Policy '#{jamf_auto_install_policy_name}'."
          end
          # - update the patch policy

          pol = jamf_patch_policy
          return unless pol

          set_policy_exclusions(pol, ttl_obj: ttl_obj)
          pol.save
          progress "Jamf: updated exccluded groups for Patch Policy '#{jamf_patch_policy_name}'."
        end

        # Update whether or not we are in self service, based on the setting in our title
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        #########################
        def update_ssvc(ttl_obj: nil)
          ttl_obj ||= title_object

          # Update the manual install policy
          pol = jamf_manual_install_policy
          return unless pol

          if ttl_obj.self_service
            pol.add_to_self_service
            pol.self_service_install_button_text = 'Install'
            msg = "Jamf: Enabled Self Service for Manual Install Policy '#{jamf_manual_install_policy_name}'."
          else
            pol.remove_from_self_service
            msg = "Jamf: Disabled Self Service for Manual Install Policy '#{jamf_manual_install_policy_name}'."
          end
          pol.save
          progress msg, log: :debug

          # TODO: if we decide to use ssvc in patch policies, enable the code below.

          # update the patch policy

          # pol = jamf_patch_policy
          # return unless pol

          # if ttl_obj.self_service
          #   pol.add_to_self_service
          #   msg = "Jamf: Enabled Self Service for Patch Policy '#{jamf_patch_policy_name}'."
          # else
          #   pol.remove_from_self_service
          #   msg = "Jamf: Disabled Self Service for Patch Policy '#{jamf_patch_policy_name}'."
          # end
          # pol.save
          # progress msg, log: :debug
        end

        # Update our self service category, based on the setting in our title
        # TODO: Allow multiple categories, and 'featuring' ?
        #
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        #########################
        def update_ssvc_category(ttl_obj: nil)
          ttl_obj ||= title_object

          # Update the manual install policy
          pol = jamf_manual_install_policy
          return unless pol

          old_cats = pol.self_service_categories.map { |c| c[:name] }
          old_cats.each { |c| pol.remove_self_service_category c }
          pol.add_self_service_category ttl_obj.self_service_category
          pol.save
          progress(
            "Jamf: Updated Self Service Category to '#{ttl_obj.self_service_category}' for Manual Install Policy '#{jamf_manual_install_policy_name}'.",
            log: :debug
          )

          # TODO: if we decide to use ssvc in patch policies, enable the code below.

          # update the patch policy

          # pol = jamf_patch_policy
          # return unless pol

          # old_cats = pol.self_service_categories.map { |c| c[:name] }
          # old_cats.each { |c| pol.remove_self_service_category c }
          # pol.add_self_service_category ttl_obj.self_service_category
          # pol.save
          # progress  "Jamf: Updated Self Service Category to '#{ttl_obj.self_service_category}' for Patch Policy '#{jamf_patch_policy_name}'.",
          #           log: :debug
        end

        # Delete an entire version from Jamf Pro
        # This includes the package, the manual install policy, the auto install policy,
        # and the patch policy.
        #
        # TODO: abandon the package-deletion thread if needed for, e.g. deleting all
        # the versions of a title. But then - how to let the admin know its done, so they
        # don't re-add a pkg with the same name?
        # Also - if we get say 10-15 deletion threads all running at once, will that
        # be a problem?
        #
        # @return [void]
        #
        #########################
        def delete_version_from_jamf
          log_debug "Deleting Version '#{version}' from Jamf"

          pols = [jamf_manual_install_policy, jamf_auto_install_policy, jamf_patch_policy]
          pols.each do |pol|
            next unless pol

            log_debug "Jamf: Starting deletion of #{pol.class} '#{pol.name}'"
            pol.delete
            progress "Jamf: Deleted #{pol.class} '#{pol.name}'", log: :info
          end

          # Delete package object
          # This is slow and it blocks, so do it in a thread and update progress every
          # 15 secs
          return unless Jamf::Package.all_names(cnx: jamf_cnx).include? jamf_pkg_name

          msg = "Jamf: Starting deletion of Package '#{jamf_pkg_name}' id #{jamf_pkg_id} at #{Time.now.strftime '%F %T'}..."
          progress msg, log: :debug

          # do this in another thread, so we can report the progress while its happening
          pkg_del_thr = Thread.new { Jamf::Package.fetch(name: jamf_pkg_name, cnx: jamf_cnx).delete }
          pkg_del_thr.name = "package-deletion-thread-#{session[:xolo_id]}"
          sleep 15
          while pkg_del_thr.alive?
            progress "... #{Time.now.strftime '%F %T'} still deleting, this is slow, sorry."
            sleep 15
          end

          msg = "Jamf: Deleted Package '#{jamf_pkg_name}' id #{jamf_pkg_id} at  #{Time.now.strftime '%F %T'}"
          progress msg, log: :debug
        end

        # Get the patch report for this version
        # @return [Arrah<Hash>] Data for each computer with this version of this title installed
        ######################
        def patch_report
          title_object.patch_report.select { |c| c[:version] == version }
        end

        # @return [String] The start of the Jamf Pro URL for GUI/WebApp access
        ################
        def jamf_gui_url
          @jamf_gui_url ||= title_object.jamf_gui_url
        end

        # @return [String] the URL for the Package that installs this version in Jamf Pro
        ######################
        def jamf_package_url
          return @jamf_package_url if @jamf_package_url
          return unless jamf_pkg_id

          @jamf_package_url = "#{jamf_gui_url}/packages.html?id=#{jamf_pkg_id}&o=r"
        end

        # @return [String] the URL for the Jamf Pro Policy that does auto-installs of this version
        ######################
        def jamf_auto_install_policy_url
          return @jamf_auto_install_policy_url if @jamf_auto_install_policy_url

          pol_id = Jamf::Policy.map_all(
            :name,
            to: :id,
            cnx: jamf_cnx
          )[jamf_auto_install_policy_name]
          return unless pol_id

          @jamf_auto_install_policy_url = "#{jamf_gui_url}/policies.html?id=#{pol_id}&o=r"
        end

        # @return [String] the URL for the Jamf Pro Policy that does manual installs of this version
        ######################
        def jamf_manual_install_policy_url
          return @jamf_manual_install_policy_url if @jamf_manual_install_policy_url

          pol_id = Jamf::Policy.map_all(
            :name,
            to: :id,
            cnx: jamf_cnx
          )[jamf_manual_install_policy_name]
          return unless pol_id

          @jamf_manual_install_policy_url = "#{jamf_gui_url}/policies.html?id=#{pol_id}&o=r"
        end

        # @return [String] the URL for the Jamf Pro Patch Policy that updates to this version
        ######################
        def jamf_patch_policy_url
          return @jamf_patch_policy_url if @jamf_patch_policy_url

          title_id = title_object.jamf_patch_title_id

          pol_id = Jamf::PatchPolicy.map_all(
            :name,
            to: :id,
            cnx: jamf_cnx
          )[jamf_patch_policy_name]
          return unless pol_id

          @jamf_manual_install_policy_url = "#{jamf_gui_url}/patchDeployment.html?softwareTitleId=#{title_id}&id=#{pol_id}&o=r"
        end

      end # JamfPro

    end # Helpers

  end # Server

end # module Xolo
