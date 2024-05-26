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
      module VersionJamfPro

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

        # FOR NOW, only one patch pol. scope will be changed
        # at release....

        # The patch policy that updates pilot installs
        # is the full prefix with this suffix:
        # JAMF_PILOT_PATCH_POLICY_SFX = '-pilot-update'

        # The patch policy that updates all installs
        # is the full prefix with this suffix:
        # JAMF_RELEASE_PATCH_POLICY_SFX = '-release-update'

        # POLICIES
        # Each version gets two policies for initial installation
        # - one for auto-installs 'xolo-autoinstall-<title>-<version>'
        #   - scoped to pilot-groups first, then  target-groups when released
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
        # Each version gets one ... or more patch policies ??
        #
        # The primary patch policy is first scoped to any pilot
        # groups.
        #
        # When the version is released, the scope is changed to All
        #
        # NOTE: remember that patch polices are pre-limited to only 'eligible'
        # machines - those that have a lower version installed and meet other
        # conditions.
        #
        # But....
        #
        #  Should it act like d3, and auto-install updates always?
        # def. for auto-install groups... but how about for the general
        # populace, like those who installed initially via SSvc??
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
        #
        # install live
        #  => xolo install title
        #
        # runs 'jamf policy -trigger xolo-install-current-<title>'
        # the xolo server maintains the trigger
        #################
        #
        # install pilot:
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

          create_patch_policy_in_jamf
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
            category: Xolo::Server::JAMF_XOLO_CATEGORY
          )
          @jamf_pkg_id = pkg.save
        rescue StandardError => e
          msg = "Jamf: Failed to create Jamf::Package '#{jamf_pkg_name}': #{e.class}: #{e}"
          log_error msg
          halt 400, msg
        end

        #
        #########################
        def create_install_policies_in_jamf
          create_manual_install_policy_in_jamf
          create_auto_install_policy_in_jamf
        end

        # The manual install policy is scoped to pilot groups before release,
        # then to all computers when released.
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

          # while in pilot, only pilot groups are targets
          unless pilot_groups_to_use.pix_empty? # it could be nil
            pilot_groups_to_use.each do |group|
              pol.scope.add_target :computer_group, group
            end
          end

          # exclusions are for always
          set_policy_exclusions pol

          if title_object.self_service
            pilot_groups_to_use.pix_empty?
            progress 'Jamf: Adding to SelfService, will only be visible to appropriate groups.', log: :debug
            pol.add_to_self_service
            pol.add_self_service_category title_object.self_service_category
            pol.self_service_description = title_object.description
            pol.self_service_display_name = title_object.display_name
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

        # When a version is released, or the title or version is updated,
        # update the target groups to
        # TODO: use this method for any updates, not just releasing
        # but releasing tells us the scope targets: pilots, or targets
        # the auto-install policy object's scope
        # Manual install policies are allways scoped to all targets
        ############################
        def set_auto_install_policy_released_targets
          pol = Jamf::Policy.fetch name: jamf_auto_install_policy_name, cnx: jamf_cnx

          # clear out any existing targets from pilot
          pol.scope.set_targets :computer_groups, []

          if title_object.target_groups.include? Xolo::Server::Title::TARGET_ALL
            pol.scope.all_targets = true
          else
            title_object.target_groups.each { |group| pol.scope.add_target :computer_group, group }
          end
          pol.save
        end

        # add excluded groups to a [patch] policy object's scope
        # @param pol [Jamf::Policy]
        ############################
        def set_policy_exclusions(pol)
          excluded_groups_to_use.each do |group|
            pol.scope.add_exclusion :computer_group, group
          end
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

        # Assign the Package to the Jamf::PatchTitle::Version for this Xolo version.
        # This 'activates' the version in Jamf Patch, and must happen before
        # patch policies can be created
        # @return [void]
        #########################
        def activate_patch_version_in_jamf
          progress "Jamf: Activating Version '#{version}' of Title '#{title_object.display_name}' by assigning package '#{jamf_pkg_name}'",
                   log: :debug

          jamf_patch_version.package = jamf_pkg_name
          title_object.jamf_patch_title.save
        end

        #########################
        def create_patch_policy_in_jamf
          # TODO: decide how many patch policies - see comments at top
          # At least one, one for pilots and then rescoped to all for release

          # TODO: How to set these, and should they be settable
          # at the Xolo::Title or  Xolo::Version level?
          #
          # allow downgrade?  Yes, if needed but think about how it works
          # and how we'd use it?
          #
          # patch_unknown_versions... yes?
          #
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

          progress "Jamf: Creating Pilot Patch Policy for Version '#{version}' of Title '#{title_object.display_name}'.",
                   log: :debug

          log_debug "jamf_cnx is: #{jamf_cnx}"

          ppol = Jamf::PatchPolicy.create(
            cnx: jamf_cnx,
            name: jamf_patch_policy_name,
            patch_title: title_object.jamf_patch_title.id,
            target_version: version,
            patch_unknown: true
          )

          log_debug "jamf_cnx is STILL: #{jamf_cnx}"

          unless pilot_groups_to_use.pix_empty?
            pilot_groups_to_use.each do |group|
              ppol.scope.add_target :computer_group, group
            end
          end

          # exclusions are for always
          set_policy_exclusions ppol

          ppol.save
        end

        #########################
        def update_patch_policy_for_release
          # TODO
        end

        # Delete an entire version from Jamf Pro
        #########################
        def delete_version_from_jamf
          log_debug "Deleting Version '#{version}' from Jamf"

          # Delete manual install policy
          if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_manual_install_policy_name
            log_debug "Jamf: Starting deletion of Policy '#{jamf_manual_install_policy_name}'"
            Jamf::Policy.fetch(name: jamf_manual_install_policy_name, cnx: jamf_cnx).delete
            progress "Jamf: Deleted Policy '#{jamf_manual_install_policy_name}'", log: :debug
          end

          # Delete auto install policy
          if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_auto_install_policy_name
            log_debug "Jamf: Starting deletion of Policy '#{jamf_auto_install_policy_name}'"
            Jamf::Policy.fetch(name: jamf_auto_install_policy_name, cnx: jamf_cnx).delete
            progress "Jamf: Deleted Policy '#{jamf_auto_install_policy_name}'", log: :debug
          end

          # Delete patch policy(s)
          if Jamf::PatchPolicy.all_names(cnx: jamf_cnx).include? jamf_patch_policy_name
            log_debug "Jamf: Starting deletion of PatchPolicy '#{jamf_patch_policy_name}'"
            Jamf::PatchPolicy.fetch(name: jamf_patch_policy_name, cnx: jamf_cnx).delete
            progress "Jamf: Deleted PatchPolicy '#{jamf_patch_policy_name}'", log: :debug
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
