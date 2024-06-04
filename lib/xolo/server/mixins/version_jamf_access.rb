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

        # Jamf objects are named with this prefix followed by <title>-<version>
        # See also:  Xolo::Server::Version#jamf_obj_name_pfx
        # which holds the full prefix for that version, and is used as the
        # full object name if appropriate (e.g. Package objects)
        JAMF_OBJECT_NAME_PFX = 'xolo-'

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
        #
        # POLICIES
        # Each version gets two policies for initial installation
        # - one for auto-installs 'xolo-autoinstall-<title>-<version>'
        #   - scoped to pilot-groups first, then  release-groups when released
        #     - xolo server maintains the scope as needed
        #   - never in self service
        #
        # - one for manual installs 'xolo-install-<title>-<version>'
        #   and self-service installs
        #   - scope to all (with exclusions) with this trigger
        #     - xolo-install-<target>-<version>
        #     - the xolo client will determine which is released when
        #       running 'xolo install <title>'
        #
        # NOTE: Other install policies can be created manually for other purposes, just
        # don't name them with xolo-ish names
        #
        # PATCH POLICIES
        # Each version gets one patch policy
        #
        # The patch policy is first scoped to  pilot groups.
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
        ##############################

        # ensure the xolo category exists
        def ensure_jamf_xolo_category
          return if Jamf::Category.all_names(cnx: jamf_cnx).include? Xolo::Server::JAMF_XOLO_CATEGORY

          log_debug "Jamf Pro: Creating category #{Xolo::Server::JAMF_XOLO_CATEGORY}"
          Jamf::Category.create(name: Xolo::Server::JAMF_XOLO_CATEGORY, cnx: jamf_cnx).save
        end

        # Create everything we need in Jamf
        ############################
        def create_in_jamf
          ensure_jamf_xolo_category

          create_pkg_in_jamf

          create_install_policies_in_jamf

          title_object.activate_patch_title_in_jamf

          activate_patch_version_in_jamf
        end

        # Create the Jamf::Package object for this version if needed
        #########################
        def create_pkg_in_jamf
          return if Jamf::Package.all_names(cnx: jamf_cnx).include? jamf_pkg_name

          progress "Jamf: Creating Jamf::Package '#{jamf_pkg_name}'", log: :info

          pkg = Jamf::Package.create(
            cnx: jamf_cnx,
            name: jamf_pkg_name,
            filename: jamf_pkg_file,
            reboot_required: reboot,
            category: Xolo::Server::JAMF_XOLO_CATEGORY,
            notes: jamf_pkg_notes
          )
          # TODO: Implement max_os, either here, or by maintaining a smart group?
          # I really which jamf would improve how package objects handle
          # OS requirements, building in the concept of min/max
          pkg.os_requirements = ">=#{min_os}"

          @jamf_pkg_id = pkg.save
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

        # Create the normal policies capable of doing the initial
        # install of this version.
        # TODO: this kinda assumes that all pkgs are 'standalone',
        # we might have to deal with them being updates only, in which
        # case we won't create these.
        #########################
        def create_install_policies_in_jamf
          create_manual_install_policy_in_jamf
          create_auto_install_policy_in_jamf
        end

        # The manual install policy is always scoped to all computers, with
        # exclusions
        #
        # The policy has a custom trigger, or can be installed via self service
        #
        #########################
        def create_manual_install_policy_in_jamf
          progress "Jamf: Creating Jamf Manual Install Policy: #{jamf_manual_install_policy_name}", log: :debug
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

          if title_object.self_service
            pilot_groups_to_use.pix_empty?
            progress 'Jamf: Adding to SelfService, will only be visible to appropriate groups.', log: :debug
            pol.add_to_self_service
            pol.add_self_service_category title_object.self_service_category
            pol.self_service_description = title_object.description
            pol.self_service_display_name = title_object.display_name
            pol.self_service_install_button_text = 'Install'
          end

          pol.enable
          pol.save
          return unless title_object.self_service

          # TODO: someday it would be nice if jamf lets us use the
          # API to assign existing icons.
          icon_file = Xolo::Server::Title.ssvc_icon_file(title)
          unless icon_file
            progress 'Jamf: NOTE: no self service icon has been uploaded for this title.'
            return
          end

          progress 'Jamf: Attaching SelfService icon to policy', log: :debug
          pol.upload :icon, icon_file if icon_file && title_object.self_service
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
        #########################
        def create_auto_install_policy_in_jamf
          progress "Jamf: Creating Jamf Auto Install Policy: #{jamf_auto_install_policy_name}", log: :debug
          pol = Jamf::Policy.create name: jamf_auto_install_policy_name, cnx: jamf_cnx

          pol.category = Xolo::Server::JAMF_XOLO_CATEGORY
          pol.add_package jamf_pkg_name
          pol.set_trigger_event :checkin, true
          pol.set_trigger_event :custom, Xolo::BLANK

          # while in pilot, only pilot groups are targets
          unless pilot_groups_to_use.pix_empty? # it could be nil
            pilot_groups_to_use.each do |group|
              pol.scope.add_target :computer_group, group
            end
          end
          # exclusions are for always
          set_policy_exclusions pol

          pol.enable
          pol.save
        end

        # set target groups in a pilot [patch] policy object's scope
        # REMEMBER TO SAVE THE POLICY LATER
        #
        # @param pol [Jamf::Policy]
        # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
        #   if nil, we'll instantiate it now
        ############################
        def set_policy_pilot_groups(pol, ttl_obj: nil)
          ttl_obj ||= title_object
          pilots = pilot_groups_to_use(ttl_obj: ttl_obj)
          pilots ||= []

          pol.scope.set_targets :computer_groups, pilots
        end

        # Set a policy to be scoped to all targets
        # REMEMBER TO SAVE THE POLICY LATER
        ############################
        def set_policy_to_all_targets(pol)
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
          targets = release_groups_to_use(ttl_obj: ttl_obj)
          targets ||= []

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

          progress "Jamf: Will assign Jamf pkg '#{jamf_pkg_name}' and create the patch policy when this version becomes visible to Jamf Pro from the Title Editor.",
                   log: :debug

          @activate_patch_version_thread = Thread.new do
            log_debug "Jamf: Starting activate_patch_version_thread waiting for version #{version} of title #{title} to become visible from the title editor"
            start_time = Time.now
            max_time = start_time + 3600
            start_time = start_time.strftime '%F %T'
            did_it = false

            while Time.now < max_time
              sleep 30
              log_debug "Jamf: checking for version #{version} of title #{title} to become visible from the title editor since #{start_time}"
              next unless title_object.jamf_patch_title(refresh: true).versions.key? version

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

        #########################
        def create_patch_policy_in_jamf
          # TODO: decide how many patch policies - see comments at top
          # Probably one: for pilots initially and then rescoped to all for release
          #
          # TODO: How to set these, and should they be settable
          # at the Xolo::Title or  Xolo::Version level?
          #
          # allow downgrade?  Yes, if needed but think about how it works
          # and how we'd use it?
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

          log_debug "Jamf: Creating Pilot Patch Policy for Version '#{version}' of Title '#{title}'."

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

          ppol.enable

          ppol.save
        end

        # @return [Jamf::Policy] The manual-install-policy for this version, if it exists
        ##########################
        def jamf_manual_install_policy
          if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_manual_install_policy_name
            Jamf::Policy.fetch(name: jamf_manual_install_policy_name, cnx: jamf_cnx)
          else
            progress(
              "Jamf: WARNING No Manual Install Policy '#{jamf_manual_install_policy_name}', it should be there.",
              log: :warn
            )
            nil
          end
        end

        # @return [Jamf::Policy] The auto-install-policy for this version, if it exists
        ##########################
        def jamf_auto_install_policy
          if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_auto_install_policy_name
            Jamf::Policy.fetch(name: jamf_auto_install_policy_name, cnx: jamf_cnx)
          else
            progress(
              "Jamf: WARNING No Auto-Install Policy '#{jamf_auto_install_policy_name}', it should be there.",
              log: :warn
            )
            nil
          end
        end

        # @return [Jamf::PatchPolicy] The auto-install-policy for this version, if it exists
        ##########################
        def jamf_patch_policy
          if Jamf::PatchPolicy.all_names(cnx: jamf_cnx).include? jamf_patch_policy_name
            Jamf::PatchPolicy.fetch(name: jamf_patch_policy_name, cnx: jamf_cnx)
          else
            progress(
              "Jamf: WARNING No Patch Policy '#{jamf_patch_policy_name}', it should be there.",
              log: :warn
            )
            nil
          end
        end

        # Apply edits to the Xolo version to Jamf as needed
        # This includes scope changes in policies, changes to pkg 'reboot' setting
        # and changes to pkg 'os_requirements'
        # Uploading a new .pkg installer happen separately
        #########################################
        def update_version_in_jamf
          unless new_data_for_update[:pilot_groups].sort == pilot_groups.sort
            # pilots
            update_pilot_groups ttl_obj: title_object
          end

          unless new_data_for_update[:release_groups].sort == release_groups.sort
            # release
            update_release_groups ttl_obj: title_object
          end

          unless new_data_for_update[:excluded_groups].sort == excluded_groups.sort
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
          return unless jamf_pkg_id
          return unless Jamf::Package.all_ids(cnx: jamf_cnx).include? jamf_pkg_id

          Jamf::Package.fetch id: jamf_pkg_id, cnx: jamf_cnx
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
        def update_pilot_groups(ttl_obj: nil)
          # nothing unless we're in pilot
          return unless status == Xolo::Server::Version::STATUS_PILOT

          # - no changes to the manual install policy: scope-target is all

          # - update the auto install policy
          pol = jamf_auto_install_policy
          if pol
            set_policy_pilot_groups(pol, ttl_obj: ttl_obj)
            pol.save
            progress "Jamf: updated pilot groups for Auto Install Policy '#{jamf_auto_install_policy_name}'."
          end

          # - update the patch policy
          pol = jamf_patch_policy
          return unless pol

          set_policy_pilot_groups(pol, ttl_obj: ttl_obj)
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
          return if [Xolo::Server::Version::STATUS_PENDING, Xolo::Server::Version::STATUS_PILOT].include? status

          # - no changes to the manual install policy: scope-target is all

          # - update the auto-install policy
          pol = jamf_auto_install_policy
          return unless pol

          set_policy_release_groups(pol, ttl_obj: ttl_obj)
          pol.save
          progress "Jamf: updated release groups for Auto Install Policy '#{jamf_auto_install_policy_name}'."

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

      end # JamfPro

    end # Helpers

  end # Server

end # module Xolo
