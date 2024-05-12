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
      module JamfProVersion

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
        # (via 'xolo install <title> <version') is named  the full
        # prefix plus this suffix.
        JAMF_POLICY_NAME_MANUAL_INSTALL_SFX = '-manual-install'

        # The policy that does auto-installs is named  the full
        # prefix plus this suffix.
        # The scope is changed as needed when a version's status
        # changes
        JAMF_POLICY_NAME_AUTO_INSTALL_SFX = '-auto-install'

        # everything xolo related in Jamf is in this category
        JAMF_XOLO_CATEGORY = 'xolo'

        #
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
        # Each version gets one patch policy
        # TODO: Versions can have pilot groups that override those for the title
        #
        # There's one patch policy for every version.
        # To start with it's scoped only to the appropriate pilot groups
        # (with exclusions) but when released, its re-scoped to everyone
        # (who has any version installed - that's what patch policies do)
        #
        # Folks who might be piloting newer versions shouldn't get the
        # patch/update because they are newer.
        # TODO: test all this.
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
          return if Jamf::Category.all_names(cnx: jamf_cnx).include? JAMF_XOLO_CATEGORY

          Jamf::Category.create(name: JAMF_XOLO_CATEGORY, cnx: jamf_cnx).save
        end

        # Create everything we need in Jamf
        def create_in_jamf
          ensure_jamf_xolo_category
          create_pkg_in_jamf
          create_install_policies_in_jamf
          create_patch_policies_in_jamf
        end

        # Create the Jamf::Package object for this version if needed
        #########################
        def create_pkg_in_jamf
          return if Jamf::Package.all_names(cnx: jamf_cnx).include? jamf_pkg_name

          log_info "Jamf: Creating Jamf::Package '#{jamf_pkg_name}'"

          pkg = Jamf::Package.create(
            cnx: jamf_cnx,
            name: jamf_pkg_name,
            filename: jamf_pkg_file,
            reboot_required: reboot,
            category: JAMF_XOLO_CATEGORY
          )
          @jamf_pkg_id = pkg.save
        rescue StandardError => e
          msg = "Jamf: Failed to create Jamf::Package '#{jamf_pkg_name}': #{e.class}: #{e}"
          log_error msg
          halt 400, { error: msg }
        end

        #
        #########################
        def create_install_policies_in_jamf
          create_manual_install_policy_in_jamf
          create_auto_install_policy_in_jamf
        end

        # The manual install policy is scoped to all computers
        # but has a custom trigger, or can be installed via self service
        #
        #########################
        def create_manual_install_policy_in_jamf
          log_debug "Jamf: Creating Jamf Manual Install Policy: #{jamf_manual_install_policy_name}"
          pol = Jamf::Policy.create name: jamf_manual_install_policy_name, cnx: jamf_cnx

          pol.category = JAMF_XOLO_CATEGORY
          pol.add_package jamf_pkg_name
          pol.set_trigger_event :checkin, false
          pol.set_trigger_event :custom, jamf_manual_install_trigger
          pol.scope.all_targets = true

          set_policy_exclusions pol

          if title_object.self_service
            pol.add_to_self_service
            pol.add_self_service_category title_object.self_service_category
            pol.self_service_description = title_object.description
          end

          pol.enable
          pol.save

          icon_file = Xolo::Server::Title.ssvc_icon_file(title)
          pol.upload :icon, icon_file if icon_file && title_object.self_service
        end

        # The auto install policy is triggered by checkin
        # but may have narrow scope targets, or may be
        # targeted to 'all' (after release)
        # Before release, the targets are those defined in #pilot_groups
        #
        # After release, the targets are changed to those
        # in title_object#target_group
        #
        # This policy is never in self service
        #########################
        def create_auto_install_policy_in_jamf
          log_debug "Jamf: Creating Jamf Auto Install Policy: #{jamf_auto_install_policy_name}"
          pol = Jamf::Policy.create name: jamf_auto_install_policy_name, cnx: jamf_cnx

          pol.category = JAMF_XOLO_CATEGORY
          pol.add_package jamf_pkg_name
          pol.set_trigger_event :checkin, true
          pol.set_trigger_event :custom, Xolo::BLANK

          # to start with, always the pilot targets
          pilot_groups.each { |group| pol.scope.add_target :computer_group, group } unless pilot_groups.pix_blank?

          set_policy_exclusions pol

          pol.enable
          pol.save
        end

        # When a version is released, update the target groups to
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

        # add excluded groups to a policy object's scope
        # @param pol [Jamf::Policy]
        ############################
        def set_policy_exclusions(pol)
          title_object.excluded_groups.each do |group|
            pol.scope.add_exclusion :computer_group, group
          end
        end

        #########################
        def create_patch_policies_in_jamf
          # make sure the jamf server activates the title
          # NOTE, may need a server.config entry for the name or id of the title editor in the
          # list of Jamf Patch Sources

          # make a patch policy for piloting

          # make a patch policy for general deployment
          # any other patch config, e.g. reporting
        end

        # Delete an entire version from Jamf Pro
        def delete_version_from_jamf
          log_debug "Deleting Version '#{version}' from Jamf"

          # spawn another thread to deal with jamf deletions
          # since they can take a long time and cause
          # timeout or end-of-file errors.
          # TODO: how to report real errors when doing this?
          thrname = "Jamf-delete-#{title}-#{version}"
          thr = Thread.new do
            log_debug "Starting thread '#{thrname}'"

            # Delete manual install policy
            if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_manual_install_policy_name
              log_debug "Jamf: Starting deletion of Policy '#{jamf_manual_install_policy_name}'"
              Jamf::Policy.fetch(name: jamf_manual_install_policy_name, cnx: jamf_cnx).delete
              log_debug "Jamf: Deleted Policy '#{jamf_manual_install_policy_name}'"
            end

            # Delete auto install policy
            if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_auto_install_policy_name
              log_debug "Jamf: Starting deletion of Policy '#{jamf_auto_install_policy_name}'"
              Jamf::Policy.fetch(name: jamf_auto_install_policy_name, cnx: jamf_cnx).delete
              log_debug "Jamf: Deleted Policy '#{jamf_auto_install_policy_name}'"
            end

            # Delete patch policy

            # Delete package object
            if Jamf::Package.all_names(cnx: jamf_cnx).include? jamf_pkg_name
              log_debug "Jamf: Starting deletion of Package '#{jamf_pkg_name}' id #{jamf_pkg_id}"
              Jamf::Package.fetch(name: jamf_pkg_name, cnx: jamf_cnx).delete
              log_debug "Jamf: Deleted Package '#{jamf_pkg_name}' id #{jamf_pkg_id}"
            end

            log_debug "Finished thread '#{thrname}'"
          end # thread.new

          thr.name = thrname
        end

      end # JamfPro

    end # Helpers

  end # Server

end # module Xolo
