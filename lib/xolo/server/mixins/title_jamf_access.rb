# Copyright 2025 Pixar
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

      # This is mixed in to Xolo::Server::Title
      # to define Title-related access to the Jamf Pro server
      #
      module TitleJamfAccess

        # Constants
        #
        ##############################
        ##############################

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

        # Instance methods
        #
        # These are available directly in title objects
        #
        ##############################
        ##############################

        # Create title-level things in jamf when creating a title.
        #
        # @return [void]
        ################################
        def create_title_in_jamf
          # ORDER MATTERS
          set_normal_ea_script_in_jamf if version_script

          # must happen after the normal ea is created
          set_installed_group_criteria_in_jamf

          if uninstall_script || !uninstall_ids.pix_empty?
            set_jamf_uninstall_script_contents
            # this creates the policy to use the script
            # must happen after the installed group is created
            jamf_uninstall_policy

            # this creates the expire policy if needed
            jamf_expire_policy if expiration && !expire_paths.pix_empty?
          end

          # Create the static group that will contain computers where this title is 'frozen'
          # Just calling this will create it if it doesn't exist.
          jamf_frozen_group

          activate_patch_title_in_jamf
        end

        # Apply any changes to Jamf as needed
        # Mostly this just sets flags indicating what needs to be updated in the
        # various version-related things in jamf - policies, self service, etc.
        #
        # @return [void]
        #########################
        def update_title_in_jamf
          # ORDER MATTERS

          # do we have a version_script? if so we maintain a 'normal' EA
          # this has to happen before updating the installed_group
          set_normal_ea_script_in_jamf if need_to_update_normal_ea_in_jamf?

          # this smart group might use the normal-EA or might use app data
          # If those have changed, we need to update it.
          set_installed_group_criteria_in_jamf if need_to_update_installed_group_in_jamf?

          # make sure the uninstall script is correct
          if need_to_update_uninstall_script_in_jamf?

            set_jamf_uninstall_script_contents

            # this creates the policy to use the script, if needed
            # which needs both the uninstall script and the installed group to exist
            jamf_uninstall_policy

          # or delete it if no longer needed
          elsif !uninstall_script_contents
            delete_uninstall_pol_and_script
            # can't expire without
          end

          # Do we need to add or delete the expire policy?
          # NOTE: if the uninstall script was deleted,
          # expiration won't do anything.
          if need_to_update_expiration?
            changes_for_update.dig(:expiration, :new).to_i.positive? ? jamf_expire_policy : delete_expire_policy
          end

          # If we don't use a version script anymore, delete the normal EA
          # this has to happen after updating the installed_group
          delete_normal_ea_from_jamf unless version_script_contents

          if jamf_ted_title_active?
            update_versions_for_title_changes_in_jamf
          else
            log_debug "Jamf: Title '#{display_name}' (#{title}) is not yet active to Jamf, nothing to update in versions."
          end
        end

        # If any title changes require updates to existing versions in
        # Jamf, this loops thru the versions and applies
        # them
        #
        # This should happen after the incoming changes have been applied to this
        # title instance
        #
        # Jamf Stuff
        # - update any policy scopes
        # - update any policy SSvc settings
        #
        # @return [void]
        ############################
        def update_versions_for_title_changes_in_jamf
          version_objects.each do |vers_obj|
            vers_obj.update_release_groups(ttl_obj: self)  if changes_for_update&.key? :release_groups
            vers_obj.update_excluded_groups(ttl_obj: self) if changes_for_update&.key? :excluded_groups
            vers_obj.update_ssvc(ttl_obj: self) if changes_for_update&.key? :self_service
            vers_obj.update_ssvc_category(ttl_obj: self) if changes_for_update&.key? :self_service_category
            # TODO: deal with icon changes: if changes_for_update&.key? :self_service_icon
          end
        end

        # do we need to update the normal EA in jamf?
        # true if our incoming changes include :version_script
        # and the new value is not empty (in which case we'll delete it)
        #
        # @return [Boolean]
        ########################
        def need_to_update_normal_ea_in_jamf?
          changes_for_update.key?(:version_script) && !changes_for_update[:version_script][:new].pix_empty?
        end

        # do we need to update the uninstall scriptin jamf?
        # true if our incoming changes include :uninstall_script OR :uninstall_ids
        # and the new value of at least one of them is not empty
        # (in which case we'll delete it)
        #
        # @return [Boolean]
        ########################
        def need_to_update_uninstall_script_in_jamf?
          return false unless changes_for_update.key?(:uninstall_script) || changes_for_update.key?(:uninstall_ids)

          # if we are here, something's changing, we have one of those keys,
          # so get the new value....
          # this might be:
          # - a String (a new script)
          # - an Array (a new list of ids)
          # - nil (we are removing uninstallability)
          changes_for_update.dig(:uninstall_script, :new) || changes_for_update.dig(:uninstall_ids, :new)
        end

        # do we need to create or delete the expire policy?
        # True if our incoming changes include :expiration
        #
        # Ignore the expire paths - even when disabling expiration
        # they can stay there, they won't mean anything.
        #
        # @return [Boolean]
        ###################################
        def need_to_update_expiration?
          changes_for_update.key?(:expiration)
        end

        # do we need to update the 'installed' smart group?
        # true if our incoming changes include the app_name or app_bundle_id
        #
        # If they changed at all, we need to update no matter what:
        #  - if they are now nil, we switched to a version script
        #
        #  - if they aren't nil but are different, we need to update
        #    the group criteria to reflect that.
        #
        # Changes to the version script, if it was in use before, don't
        # require us to change the smart group
        #
        #
        # @return [Boolean]
        #########################
        def need_to_update_installed_group_in_jamf?
          changes_for_update[:app_name] || changes_for_update[:app_bundle_id]
        end

        # Create or update the smartgroup in jamf that contains all macs
        # with any version of this title installed.
        #
        # @return [void]
        #####################################
        def set_installed_group_criteria_in_jamf
          progress "Jamf: Setting criteria for smart group '#{jamf_installed_group_name}'", log: :info

          jamf_installed_group.criteria = Jamf::Criteriable::Criteria.new(jamf_installed_group_criteria)
          jamf_installed_group.save

          log_debug 'Jamf: Sleeping to let Jamf server see change to the Installed smart group.'
          sleep 10
        end

        # Create or fetch the script that uninstalls this title from a Mac
        #
        # @return [Jamf::Script] The Jamf Script for uninstalling this title
        #####################################
        def jamf_uninstall_script
          return @jamf_uninstall_script if @jamf_uninstall_script

          if Jamf::Script.all_names(cnx: jamf_cnx).include? jamf_uninstall_script_name
            @jamf_uninstall_script = Jamf::Script.fetch name: jamf_uninstall_script_name, cnx: jamf_cnx
          else
            return if deleting?

            progress "Jamf: Creating Uninstall script '#{jamf_uninstall_script_name}'", log: :info
            @jamf_uninstall_script = Jamf::Script.create(
              name: jamf_uninstall_script_name,
              script_contents: uninstall_script_contents,
              cnx: jamf_cnx
            )
            @jamf_uninstall_script.save
          end
          @jamf_uninstall_script
        end

        # Create or fetch the policy that runs the jamf uninstall script
        #
        # @return [Jamf::Policy] The Jamf Policy for uninstalling this title
        #####################################
        def jamf_uninstall_policy
          return @jamf_uninstall_policy if @jamf_uninstall_policy

          if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_uninstall_policy_name
            @jamf_uninstall_policy = Jamf::Policy.fetch name: jamf_uninstall_policy_name, cnx: jamf_cnx
          else
            return if deleting?

            progress "Jamf: Creating Uninstall policy: '#{jamf_uninstall_policy_name}'", log: :info

            @jamf_uninstall_policy = Jamf::Policy.create name: jamf_uninstall_policy_name, cnx: jamf_cnx
            @jamf_uninstall_policy.category = Xolo::Server::JAMF_XOLO_CATEGORY
            @jamf_uninstall_policy.add_script jamf_uninstall_script_name
            @jamf_uninstall_policy.set_trigger_event :checkin, false
            @jamf_uninstall_policy.set_trigger_event :custom, jamf_uninstall_policy_name
            @jamf_uninstall_policy.scope.add_target(:computer_group, jamf_installed_group_name)
            if valid_forced_exclusion_group_name
              @jamf_uninstall_policy.scope.set_exclusions :computer_groups, [valid_forced_exclusion_group_name]
            end
            @jamf_uninstall_policy.frequency = :ongoing
            @jamf_uninstall_policy.enable
            @jamf_uninstall_policy.save
          end

          @jamf_uninstall_policy
        end

        # Create or fetch the policy that expires a title
        #
        # @return [Jamf::Policy] The Jamf Policy for expiring this title
        #####################################
        def jamf_expire_policy
          return @jamf_expire_policy if @jamf_expire_policy

          if Jamf::Policy.all_names(cnx: jamf_cnx).include? jamf_expire_policy_name
            @jamf_expire_policy = Jamf::Policy.fetch name: jamf_expire_policy_name, cnx: jamf_cnx
          else
            return if deleting?

            progress "Jamf: Creating Expiration policy: '#{jamf_expire_policy_name}'", log: :info

            @jamf_expire_policy = Jamf::Policy.create name: jamf_expire_policy_name, cnx: jamf_cnx
            @jamf_expire_policy.category = Xolo::Server::JAMF_XOLO_CATEGORY
            @jamf_expire_policy.run_command = "#{Xolo::Server::Title::CLIENT_EXPIRE_COMMAND} #{title}"
            @jamf_expire_policy.set_trigger_event :checkin, true
            @jamf_expire_policy.set_trigger_event :custom, jamf_expire_policy_name
            @jamf_expire_policy.scope.add_target(:computer_group, jamf_installed_group_name)
            if valid_forced_exclusion_group_name
              @jamf_expire_policy.scope.set_exclusions :computer_groups, [valid_forced_exclusion_group_name]
            end
            @jamf_expire_policy.frequency = :daily
            @jamf_expire_policy.enable
            @jamf_expire_policy.save
          end

          @jamf_expire_policy
        end

        # Create or fetch he smartgroup in jamf that contains all macs
        # with any version of this title installed.
        # If we are deleting and it doesn't exist, return nil.
        #
        # @return [Jamf::ComputerGroup, nil] The Jamf ComputerGroup for this title's installed computers
        #####################################
        def jamf_installed_group
          return @jamf_installed_group if @jamf_installed_group

          if Jamf::ComputerGroup.all_names(cnx: jamf_cnx).include? jamf_installed_group_name
            @jamf_installed_group = Jamf::ComputerGroup.fetch(
              name: jamf_installed_group_name,
              cnx: jamf_cnx
            )
          else
            return if deleting?

            progress "Jamf: Creating smart group '#{jamf_installed_group_name}'", log: :info

            @jamf_installed_group = Jamf::ComputerGroup.create(
              name: jamf_installed_group_name,
              type: :smart,
              cnx: jamf_cnx
            )
            @jamf_installed_group.save
          end
          @jamf_installed_group
        end

        # The criteria for the smart group in Jamf that contains all Macs
        # with any version of this title installed
        #
        # If we have, or are about to update to, a version_script (EA) then use it,
        # otherwise use the app_name and app_bundle_id.
        #
        # @return [Array<Jamf::Criteriable::Criterion>]
        ###################################
        def jamf_installed_group_criteria
          have_vers_script =
            if changes_for_update&.dig :version_script
              changes_for_update[:version_script][:new]
            else
              version_script
            end

          # If we have a version_script, use the ea
          if have_vers_script
            [
              Jamf::Criteriable::Criterion.new(
                and_or: :and,
                name: jamf_normal_ea_name,
                search_type: 'is not',
                value: Xolo::BLANK
              )
            ]

          # No version script, so we must be using app data
          else
            aname = changes_for_update.dig(:app_name, :new) || app_name
            abundle = changes_for_update.dig(:app_bundle_id, :new) || app_bundle_id

            [
              Jamf::Criteriable::Criterion.new(
                and_or: :and,
                name: 'Application Title',
                search_type: 'is',
                value: aname
              ),

              Jamf::Criteriable::Criterion.new(
                and_or: :and,
                name: 'Application Bundle ID',
                search_type: 'is',
                value: abundle
              )
            ]
          end
        end

        # Set the script contents of the jamf_uninstall_script, if we have one
        #
        # @return [void]
        ################################
        def set_jamf_uninstall_script_contents
          return unless uninstall_script_contents

          progress "Jamf: Setting the code for the uninstall script '#{jamf_uninstall_script_name}'", log: :info
          jamf_uninstall_script.code = uninstall_script_contents
          jamf_uninstall_script.save
        end

        # Create or update a 'normal' EA that matches the Patch EA for this title,
        # so that it can be used in smart groups and adv. searches.
        # (Patch EAs aren't available for use in smart group critera)
        #
        # If we have one already but are deleting it, that happens elsewhere
        #
        # @return [void]
        ################################
        def set_normal_ea_script_in_jamf
          msg = "Jamf: Setting regular extension attribute '#{jamf_normal_ea_name}' to use version_script"
          progress msg, log: :info

          # this is our incoming or already-existing EA script
          scr = version_script_contents

          # nothing to do if its nil, if we need to delete it, that'll happen later
          return if scr.pix_empty?

          # nothing to do if it hasn't changed.
          return if current_action == :updating && !(changes_for_update&.key? :version_script)

          jamf_normal_ea.script = scr
          jamf_normal_ea.save
        end

        # Create or fetch the 'normal' EA in jamf
        # If we are deleting and it doesn't exist, return nil.
        #
        # @return [Jamf::ComputerExtensionAttribute] The 'normal' Jamf ComputerExtensionAttribute for this title
        ########################
        def jamf_normal_ea
          return @jamf_normal_ea if @jamf_normal_ea

          if Jamf::ComputerExtensionAttribute.all_names(cnx: jamf_cnx).include? jamf_normal_ea_name
            @jamf_normal_ea = Jamf::ComputerExtensionAttribute.fetch(name: jamf_normal_ea_name, cnx: jamf_cnx)

          else
            return if deleting?

            msg = "Jamf: Creating regular extension attribute '#{jamf_normal_ea_name}' for use in smart group"
            progress msg, log: :info

            @jamf_normal_ea = Jamf::ComputerExtensionAttribute.create(
              name: jamf_normal_ea_name,
              description: "The version of xolo title '#{title}' installed on the machine",
              data_type: :string,
              enabled: true,
              cnx: jamf_cnx
            )
            @jamf_normal_ea.save

          end
          @jamf_normal_ea
        end

        # Do we need to accept the xolo ea in jamf?
        #
        # True if
        # - title activation, and version_script
        # - any time version_script changes
        # - any time we switch from bundledata to version_script
        #
        # @need_to_accept_xolo_ea_in_jamf is set true by these methods
        # - Title#create_ted_ea
        # - Title#update_ted_ea
        #
        # @return [Boolean]
        #########################
        def need_to_accept_xolo_ea_in_jamf?
          @need_to_accept_xolo_ea_in_jamf
        end

        # The Jamf Patch Source that is connected to the Title Editor
        # This must be manually configured in the Jamf server and the Xolo server
        #
        # @return [Jamf::PatchSource] The Jamf Patch Source
        #########################
        def jamf_ted_patch_source
          @jamf_ted_patch_source ||=
            Jamf::PatchSource.fetch(name: Xolo::Server.config.ted_patch_source, cnx: jamf_cnx)
        end

        # The titles available from the Title Editor via its
        # Jamf Patch Source. These are titles have have been enabled
        # in the Title Editor
        #
        # available_titles returns a Hash for each available title, with these keys:
        #
        #   name_id: [String] The Xolo 'title' or the Title Editor 'id'
        #
        #   current_version: [String] NOTE: This
        #     may be a version that is in 'pilot' from Xolo's POV, but
        #     from the TEd's POV, it has been made available to Jamf.
        #
        #   publisher: [String]
        #
        #   last_modified: [Time]
        #
        #   app_name: [String] The Xolo 'display_name'
        #
        # but we map it to just the name_id
        #
        # @return [Array<String>] info about the available titles
        #########################
        def jamf_ted_available_titles
          # Don't cache this in an instance var, it changes during the
          # life of our title instance
          # jamf_ted_patch_source.available_titles.map { |t| t[:name_id] }
          # Also NOTE: "available" means not only enabled
          # in the title editor, but also not already active in jamf.
          # So any given title will either be here or in
          # jamf_active_ted_titles, but never both.
          jamf_ted_patch_source.available_name_ids
        end

        # @return [Boolean] Is this xolo title available in Jamf?
        ########################
        def jamf_ted_title_available?
          jamf_ted_available_titles.include? title
        end

        # create/activate the patch title in Jamf Pro, if not already done.
        #
        # This 'subscribes' Jamf to the title in the title editor
        # It must be enabled in the Title Editor first, meaning
        # it has at least one requirement, and at least one enabled patch/version.
        #
        # The 'stub' patch version should allow this when we create the title.
        #
        # Xolo should have enabled it in the Title editor before we
        # reach this point.
        #
        ##########################
        def activate_patch_title_in_jamf
          if jamf_ted_title_active?
            log_debug "Jamf: Title '#{display_name}' (#{title}) is already active in Jamf"
            return
          end

          # wait up to 60secs for the title to become available
          counter = 0
          until jamf_ted_title_available? || counter == 12
            log_debug "Jamf: Waiting for title '#{display_name}' (#{title}) to become available from the Title Editor"
            sleep 5
            counter += 1
          end

          unless jamf_ted_title_available?
            msg = "Jamf: Title '#{title}' is not yet available to Jamf. Make sure it has at least one version enabled in the Title Editor"
            log_error msg
            raise Xolo::NoSuchItemError, msg
          end

          # This creates/activates the title if needed
          jamf_patch_title

          accept_xolo_patch_ea_in_jamf
        end

        # This method should only be called when we *expect* to need to accept the EA -
        # not only when we first activate a title with a version script, but when the version_script
        # has changed, or been added, replacing app_name and app_bundle_id.
        #
        # If the EA needs acceptance when this method starts, we accept it and we're done.
        #
        # If not (there is no EA, or it's already accepted) then we spin off a thread that
        # waits up to an hour for Jamf to notice the change from the Title Editor and require
        # re-acceptance.
        #
        # As soon as we see that Jamf shows accepted: false, we'll accept it and be done.
        #
        # If we make it for an hour and never see the expected need for acceptance, we
        # log it and send an alert about it.
        #
        # TODO: when this is implemented in ruby-jss, use the implementation
        #
        # NOTE: PATCHing the ea of the title requires CRUD privs for computer ext attrs
        #
        # @return [void]
        ############################
        def accept_xolo_patch_ea_in_jamf
          return unless need_to_accept_xolo_ea_in_jamf?

          # return with warning if we aren't auto-accepting
          unless Xolo::Server.config.jamf_auto_accept_xolo_eas
            msg = "Jamf: IMPORTANT: Before adding any versions, the Extension Attribute (version-script) for this title must be accepted manually in Jamf Pro at #{jamf_patch_ea_url} under the 'Extension Attribute' tab (click 'Edit') "
            progress msg
            log_debug 'Admin informed about accepting EA/version-script manually'
            return
          end

          # this is true if the Jamf server already knows it needs to be accepted
          # so just do it now
          if jamf_patch_ea_awaiting_acceptance?
            progress "Jamf: Auto-accepting use of version-script ExtensionAttribute '#{ted_ea_key}'", log: :info
            accept_patch_ea_in_jamf_via_api
            return
          end

          # If not, we are here because we expect it will need acceptance soon
          # So we call this method to wait for Jamf to notice that,
          # checking in the background for up  to an hour.
          auto_accept_patch_ea_in_thread
        end

        # Wait for up to an hour for Jamf to notice that our TEd EA needs to be
        # accepted, and then do it
        #####################
        def auto_accept_patch_ea_in_thread
          # don't do this if there's already one running for this instance
          if @auto_accept_ea_thread&.alive?
            log_debug "Jamf: auto_accept_ea_thread already running. Caller: #{caller_locations.first}"
            return
          end

          progress "Jamf: version-script ExtAttr for this title '#{ted_ea_key}' will be auto-accepted when Jamf sees the changes in the Title Editor"

          @auto_accept_ea_thread = Thread.new do
            log_debug "Jamf: Starting auto_accept_ea_thread for #{title}"
            start_time = Time.now
            max_time = start_time + Xolo::Server::MAX_JAMF_WAIT_FOR_TITLE_EDITOR

            start_time = start_time.strftime '%F %T'
            did_it = false

            while Time.now < max_time
              sleep 30

              # refresh our jamf connection cuz it might expire if this takes a while, esp if using
              # an APIClient
              jamf_cnx(refresh: true) if jamf_cnx.token.secs_remaining < 90

              log_debug "Jamf: checking for expected (re)acceptance of version-script ExtensionAttribute '#{ted_ea_key}' since #{start_time}"
              next unless jamf_patch_ea_awaiting_acceptance?

              accept_patch_ea_in_jamf_via_api
              log_info "Jamf: Auto-accepted use of version-script ExtensionAttribute '#{ted_ea_key}'"
              did_it = true
              break
            end # while

            return if did_it

            msg = "Jamf: Expected to (re)accept version-script ExtensionAttribute '#{ted_ea_key}', but Jamf hasn't seen the change in over #{Xolo::Server::MAX_JAMF_WAIT_FOR_TITLE_EDITOR} secs. Please investigate."
            log_error msg, alert: true
          end # thread
        end

        # Does the Jamf Title currently need its EA to be accepted, according to Jamf Pro?
        #
        # NOTE: Jamf might not see the need for this immediately, so we set
        # @need_to_accept_xolo_ea_in_jamf and define #need_to_accept_xolo_ea_in_jamf?
        # and use them to determine if we should wait for this to become true.
        #
        # @return [Boolean]
        #################################
        def jamf_patch_ea_awaiting_acceptance?
          ead = jamf_patch_ea_data
          return unless ead

          !ead[:accepted]
        end

        # Does the EA for this title in Jamf match the version script we know about?
        #
        # If we don't have a version script, then we don't really care what Jamf has at the moment,
        # Jamf's should go away once it catches up with the title editor.
        #
        # But if we do have one, and Jamf has something different, we'll need to accept it,
        # if configured to do so automatically.
        #
        # This method just tells us the current situation about our version script
        # vs the Jamf Patch EA.
        #
        # @param new_version_script [String, nil] If updating, this is the new incoming version script.
        #
        # @return [Boolean, nil] nil if we have no version script,
        #   otherwise, does jamf match our version_script?
        #########################
        def jamf_patch_ea_matches_version_script?
          # our current version script - nil if we currently don't have one
          our_version_script = version_script_contents

          # we don't have one, so if Jamf does at the moment, it'll go away soon
          # when jamf catches up with the title editor.
          return unless our_version_script

          # does jamf's script match ours?
          our_version_script.chomp == jamf_patch_ea_contents.chomp
        end

        # The version_script as a Jamf Extension Attribute,
        # once the title as been activated in Jamf.
        #
        # This is a hash of data returned from the JP API endpoint:
        #    "v2/patch-software-title-configurations/#{jamf_patch_title_id}/extension-attributes"
        # which has these keys:
        #
        #   :accepted [Boolean] has it been accepted for the title?
        #
        #   :eaId [String] the 'key' of the EA from the title editor
        #
        #   :displayName [String] the displayname from the title editor, for titles
        #   maintained by xolo, it's the same as the eaId
        #
        #   :scriptContent [String] the Base64-encoded script of the EA.
        #
        # TODO: when this gets implemented in ruby-jss, use that implementation
        # and return the patch title ea object.
        #
        # NOTE: The title must be activated in Jamf before accessing this.
        #
        # NOTE: We fetch this hash every time this method is called, since we may
        #   be waiting for jamf to notice that the EA has changed in the Title Editor
        #   and needs re-acceptance
        #
        # NOTE: While Jamf Patch allows for multiple EAs per title, the Title Editor only
        #   allows for one. So even tho the data comes back in an array, we only care about
        #   the first (and only) value.
        #
        # @return [Hash] the data from the JPAPI endpoint,
        #   nil if the title has no EA at the moment
        ########################
        def jamf_patch_ea_data
          return unless jamf_patch_title_id

          jamf_cnx.jp_get("v2/patch-software-title-configurations/#{jamf_patch_title_id}/extension-attributes").first
        end

        # API call to accept the version-script EA in Jamf Pro
        # TODO: when this gets implemented in ruby-jss, use that implementation
        #
        # @return [void]
        ########################
        def accept_patch_ea_in_jamf_via_api
          patchdata = <<~ENDPATCHDATA
            {
              "extensionAttributes": [
                {
                  "accepted": true,
                  "eaId": "#{ted_ea_key}"
                }
              ]
            }
          ENDPATCHDATA
          jamf_cnx.jp_patch "v2/patch-software-title-configurations/#{jamf_patch_title_id}", patchdata
          log_debug "Jamf: Auto-accepted ExtensionAttribute '#{ted_ea_key}'"
        end

        # the script contents of the Jamf Patch EA that comes from our version_script
        # @return [String, nil] nil if there is none, or the title isn't active yet
        ##############################
        def jamf_patch_ea_contents
          jea_data = jamf_patch_ea_data
          return unless jea_data && jea_data[:scriptContents]

          Base64.decode64 jea_data[:scriptContents]
        end

        # the script contents of the Normal Jamf EA that comes from our version_script
        # @return [String, nil] nil if there is none
        ##############################
        def jamf_normal_ea_contents
          jamf_normal_ea.script
        end

        # The titles active in Jamf Patch Management from the Title Editor
        # This takes into account that other Patch Sources may have titles with the
        # same 'name_id' (the xolo 'title')
        # A hash keyed by the title, with values of the jamf title id
        #
        # @return [Hash {String =>  Integer}] The xolo titles that are active in Jamf Patch Management
        ########################
        def jamf_active_ted_titles(refresh: false)
          @jamf_active_ted_titles = nil if refresh
          return @jamf_active_ted_titles if @jamf_active_ted_titles

          @jamf_active_ted_titles = {}
          active_from_ted = Jamf::PatchTitle.all(:refresh, cnx: jamf_cnx).select do |t|
            t[:source_id] == jamf_ted_patch_source.id
          end
          active_from_ted.each { |t| @jamf_active_ted_titles[t[:name_id]] = t[:id] }
          @jamf_active_ted_titles
        end

        # @return [Boolean] Is this xolo title currently active in Jamf?
        ########################
        def jamf_ted_title_active?
          jamf_active_ted_titles(refresh: true).key? title
        end

        # The Jamf ID of the Patch Title for this xolo title
        # if it has been activated in jamf.
        #
        # @return [Integer, nil] The Jamf ID of this title, if it is active in Jamf
        ########################
        def jamf_patch_title_id
          @jamf_patch_title_id ||= jamf_active_ted_titles(refresh: true)[title]
        end

        # Create or fetch the patch title object for this xolo title.
        # If we are deleting and it doesn't exist, return nil.
        #
        # @param refresh [Boolean] re-fetch the patch title from Jamf?
        # @return [Jamf::PatchTitle, nil] The Jamf Patch Title for this Xolo Title
        ########################
        def jamf_patch_title(refresh: false)
          @jamf_patch_title = nil if refresh
          return @jamf_patch_title if @jamf_patch_title

          breaktime = Time.now + Xolo::Server::MAX_JAMF_WAIT_FOR_TITLE_EDITOR
          until jamf_ted_title_available? || jamf_ted_title_active?
            if Time.now > breaktime
              raise Xolo::ServerError,
                    "Jamf: Title '#{title}' is not available in Jamf after waiting #{Xolo::Server::MAX_JAMF_WAIT_FOR_TITLE_EDITOR} seconds"
            end

            log_debug "Waiting a long time for title '#{title}' to become available from TEd. Checking every 10 secs"
            sleep 10
          end

          if jamf_ted_title_active?
            @jamf_patch_title = Jamf::PatchTitle.fetch(id: jamf_patch_title_id, cnx: jamf_cnx)

          else
            return if deleting?

            msg = "Jamf: Activating Patch Title '#{display_name}' (#{title}) from the Title Editor Patch Source '#{Xolo::Server.config.ted_patch_source}'"
            progress msg, log: :info

            @jamf_patch_title =
              Jamf::PatchTitle.create(
                name: display_name,
                source: Xolo::Server.config.ted_patch_source,
                name_id: title,
                cnx: jamf_cnx
              )
            @jamf_patch_title.category = Xolo::Server::JAMF_XOLO_CATEGORY
            @jamf_patch_title.save

          end
          @jamf_patch_title
        end

        # Delete an entire title from Jamf Pro
        ########################
        def delete_title_from_jamf
          # ORDER MATTERS
          delete_expire_policy
          delete_uninstall_pol_and_script
          delete_frozen_group_from_jamf
          delete_installed_group_from_jamf
          delete_normal_ea_from_jamf
          delete_patch_title_from_jamf
        end

        # Delete the 'installed' smart group
        # @return [void]
        ######################################
        def delete_installed_group_from_jamf
          grp_id = Jamf::ComputerGroup.valid_id jamf_installed_group_name, cnx: jamf_cnx
          return unless grp_id

          progress "Jamf: Deleting smart group '#{jamf_installed_group_name}'", log: :info
          Jamf::ComputerGroup.delete grp_id, cnx: jamf_cnx
          # give the server time to see the deletion
          log_debug 'Sleeping to let server see deletion of smart group'
          sleep 10
        end

        # Delete the 'frozen' static group
        # @return [void]
        ######################################
        def delete_frozen_group_from_jamf
          grp_id = Jamf::ComputerGroup.valid_id jamf_frozen_group_name, cnx: jamf_cnx
          return unless grp_id

          progress "Jamf: Deleting static group '#{jamf_frozen_group_name}'", log: :info
          Jamf::ComputerGroup.delete grp_id, cnx: jamf_cnx
        end

        # Delete the 'normal' computer ext attr matching the Patch EA
        # @return [void]
        ######################################
        def delete_normal_ea_from_jamf
          ea_id = Jamf::ComputerExtensionAttribute.valid_id jamf_normal_ea_name, cnx: jamf_cnx
          return unless ea_id

          progress "Jamf: Deleting regular extension attribute '#{jamf_normal_ea_name}'", log: :info
          Jamf::ComputerExtensionAttribute.delete ea_id, cnx: jamf_cnx
        end

        # Delete the patch title
        # NOTE: jamf api user must have 'delete computer ext. attribs' permmissions
        ##############################
        def delete_patch_title_from_jamf
          return unless jamf_ted_title_active?

          pt_id = Jamf::PatchTitle.map_all(:id, to: :name_id, cnx: jamf_cnx).invert[title]
          return unless pt_id

          msg = "Jamf: Deleting (unsubscribing) title '#{display_name}' (#{title}}) in Jamf Patch Management"
          progress msg, log: :info
          Jamf::PatchTitle.delete pt_id, cnx: jamf_cnx
        end

        #########################
        def delete_uninstall_pol_and_script
          # uninstall the policy first if it exists
          pol_id = Jamf::Policy.valid_id jamf_uninstall_policy_name, cnx: jamf_cnx
          if pol_id
            progress "Jamf: Deleting uninstall policy '#{jamf_uninstall_policy_name}'", log: :info
            Jamf::Policy.delete pol_id, cnx: jamf_cnx
          end

          script_id = Jamf::Script.valid_id jamf_uninstall_script_name, cnx: jamf_cnx
          return unless script_id

          progress "Jamf: Deleteing uninstall script '#{jamf_uninstall_script_name}'", log: :info
          Jamf::Script.delete script_id, cnx: jamf_cnx
        end

        #############################
        def delete_expire_policy
          pol_id = Jamf::Policy.valid_id jamf_expire_policy_name, cnx: jamf_cnx
          return unless pol_id

          progress "Jamf: Deleting expiration policy '#{jamf_expire_policy_name}'", log: :info
          Jamf::Policy.delete pol_id, cnx: jamf_cnx
        end

        # Freeze or thaw an array of computers for a title
        #
        # @param action [Symbol] :freeze or :thaw
        #
        # @param computers [Array<String>, String] The computer name[s] to freeze or thaw. To thaw
        #   all computers pass Xolo::TARGET_ALL (freeze all is not allowed)
        #
        # @return [Hash] Keys are computer names, values are Xolo::OK or an error message
        #################################
        def freeze_or_thaw_computers(action:, computers:)
          return unless %i[freeze thaw].include? action

          # convert to an array if it's a single string
          computers = [computers].flatten

          result, changes_to_log =
            if action == :thaw
              thaw_computers(computers: computers)
            else
              freeze_computers(computers: computers)
            end # if action ==

          jamf_frozen_group.save

          unless changes_to_log.empty?
            action_msg =
              if action == :freeze
                "Froze computers: #{changes_to_log.join(', ')}"
              else
                "Thawed computers: #{changes_to_log.join(', ')}"
              end

            log_change msg: action_msg
          end

          result
        end

        # Create or fetch static in jamf that contains macs with this title 'frozen'
        # If we are deleting and it doesn't exist, return nil.
        #
        # @return [Jamf::ComputerGroup, nil] The Jamf ComputerGroup for this title's frozen computers
        #####################################
        def jamf_frozen_group
          return @jamf_frozen_group if @jamf_frozen_group

          if Jamf::ComputerGroup.all_names(cnx: jamf_cnx).include? jamf_frozen_group_name
            @jamf_frozen_group = Jamf::ComputerGroup.fetch name: jamf_frozen_group_name, cnx: jamf_cnx
          else
            return if deleting?

            progress "Jamf: Creating static group '#{jamf_frozen_group_name}' with no members at the moment", log: :info

            @jamf_frozen_group = Jamf::ComputerGroup.create(
              name: jamf_frozen_group_name,
              type: :static,
              cnx: jamf_cnx
            )
            @jamf_frozen_group.save

          end
          @jamf_frozen_group
        end

        # thaw some computers
        # see #freeze_or_thaw_computers
        ##############
        def thaw_computers(computers:)
          result = {}
          thaws_to_log = []

          if computers.include? Xolo::TARGET_ALL
            log_info "Thawing all computers for title: '#{title}'"
            jamf_frozen_group.clear
            result[Xolo::TARGET_ALL] = Xolo::OK
            thaws_to_log << Xolo::TARGET_ALL
          else

            grp_members = jamf_frozen_group.member_names
            computers.each do |comp|
              if grp_members.include? comp
                jamf_frozen_group.remove_member comp
                log_info "Thawed computer '#{comp}' for title '#{title}'"
                result[comp] = Xolo::OK
                thaws_to_log << comp
              else
                log_debug "Cannot thaw computer '#{comp}' for title '#{title}', not frozen"
                result[comp] = "#{Xolo::ERROR}: Not frozen"
              end # if  grp_members.include? comp
            end # computers.each
          end # if computers.include?

          [result, thaws_to_log]
        end

        # freeze some computers
        # see #freeze_or_thaw_computers
        ##############
        def freeze_computers(computers:)
          result = {}
          freezes_to_log = []

          comp_names = Jamf::Computer.all_names cnx: jamf_cnx
          grp_members = jamf_frozen_group.member_names

          computers.each do |comp|
            if grp_members.include? comp
              log_info "Not freezing computer '#{comp}' for title '#{title}', already frozen"
              result[comp] = "#{Xolo::ERROR}: Already frozen"
            elsif comp_names.include? comp
              log_info "Freezing computer '#{comp}' for title '#{title}'"
              jamf_frozen_group.add_member comp
              result[comp] = Xolo::OK
              freezes_to_log << comp
            else
              log_debug "Cannot freeze computer '#{comp}' for title '#{title}', no such computer"
              result[comp] = "#{Xolo::ERROR}: No computer with that name"
            end # if comp_names.include
          end # computers.each

          [result, freezes_to_log]
        end

        # Return the members of the 'frozen' static group for a title
        #
        # @return [Hash{String => String}] computer name => user name
        #################################
        def frozen_computers
          members = {}

          comps = jamf_frozen_group.member_names
          comps_to_users = Jamf::Computer.map_all :name, to: :username, cnx: jamf_cnx

          comps.each { |comp| members[comp] = comps_to_users[comp] || 'unknown' }

          members
        end

        # Get the patch report for this title.
        # It's the JPAPI report data with each hash having a frozen: key added
        #
        # TODO: rework this when all the paging stuff is handled by ruby-jss
        #
        # @param vers [String, nil] Limit the report to a specific version
        #
        # @return [Arrah<Hash>] Data for each computer with any version of this title installed
        ######################
        def patch_report(vers: nil)
          vers = Xolo::Server::Helpers::JamfPro::PATCH_REPORT_UNKNOWN_VERSION if vers == Xolo::UNKNOWN
          vers &&= CGI.escape vers.to_s

          page_size = Xolo::Server::Helpers::JamfPro::PATCH_REPORT_JPAPI_PAGE_SIZE
          page = 0
          paged_rsrc = "#{patch_report_rsrc}?page=#{page}&page-size=#{page_size}"
          paged_rsrc << "&filter=version%3D%3D#{vers}" if vers

          report = []
          loop do
            data = jamf_cnx.jp_get(paged_rsrc)[:results]
            log_debug "GOT #{paged_rsrc}  >>> results size: #{data.size}"
            break if data.empty?

            report += data
            page += 1
            paged_rsrc = "#{patch_report_rsrc}?page=#{page}&page-size=#{page_size}"
            paged_rsrc << "&filter=version%3D%3D#{vers}" if vers
          end

          # log_debug "REPORT: #{report}"

          frozen_comps = frozen_computers.keys
          report.each do |h|
            h[:frozen] = frozen_comps.include? h[:computerName]
            h[:version] = Xolo::UNKNOWN if h[:version] == Xolo::Server::Helpers::JamfPro::PATCH_REPORT_UNKNOWN_VERSION
          end
          report
        end

        # @return [String] The start of the Jamf Pro URL for GUI/WebApp access
        ################
        def jamf_gui_url
          return @jamf_gui_url if @jamf_gui_url

          host = Xolo::Server.config.jamf_gui_hostname
          host ||= Xolo::Server.config.jamf_hostname
          port = Xolo::Server.config.jamf_gui_port
          port ||= Xolo::Server.config.jamf_port

          @jamf_gui_url = "https://#{host}:#{port}"
        end

        # @return [String] the URL for the Frozen static group in Jamf Pro
        ######################
        def jamf_frozen_group_url
          return @jamf_frozen_group_url if @jamf_frozen_group_url

          gr_id = Jamf::ComputerGroup.valid_id jamf_frozen_group_name, cnx: jamf_cnx
          return unless gr_id

          @jamf_frozen_group_url = "#{jamf_gui_url}/staticComputerGroups.html?id=#{gr_id}&o=r"
        end

        # @return [String] the URL for the Frozen statig group in Jamf Pro
        ######################
        def jamf_installed_group_url
          return @jamf_installed_group_url if @jamf_installed_group_url

          gr_id = Jamf::ComputerGroup.valid_id jamf_installed_group_name, cnx: jamf_cnx
          return unless gr_id

          @jamf_installed_group_url = "#{jamf_gui_url}/smartComputerGroups.html?id=#{gr_id}&o=r"
        end

        # @return [String] the URL for the Patch Title in Jamf Pro
        #####################
        def jamf_patch_title_url
          @jamf_patch_title_url ||= "#{jamf_gui_url}/view/computers/patch/#{jamf_patch_title_id}"
        end

        # @return [String] the URL for the Patch EA in Jamf Pro
        ######################
        def jamf_patch_ea_url
          return @jamf_patch_ea_url if @jamf_patch_ea_url
          return unless version_script

          @jamf_patch_ea_url = "#{jamf_patch_title_url}?tab=extension"
        end

        # @return [String] the URL for the Normal EA in Jamf Pro
        ######################
        def jamf_normal_ea_url
          return @jamf_normal_ea_url if @jamf_normal_ea_url
          return unless version_script

          ea_id = Jamf::ComputerExtensionAttribute.valid_id jamf_normal_ea_name, cnx: jamf_cnx
          return unless ea_id

          @jamf_normal_ea_url = "#{jamf_gui_url}/computerExtensionAttributes.html?id=#{ea_id}&o=r"
        end

        # @return [String] the URL for the uninstall script in Jamf Pro
        ######################
        def jamf_uninstall_script_url
          return @jamf_uninstall_script_url if @jamf_uninstall_script_url
          return unless uninstallable?

          scr_id = Jamf::Script.valid_id jamf_uninstall_script_name, cnx: jamf_cnx
          return unless scr_id

          @jamf_uninstall_script_url = "#{jamf_gui_url}/view/settings/computer-management/scripts/#{scr_id}?tab=script"
        end

        # @return [String] the URL for the uninstall policy in Jamf Pro
        ######################
        def jamf_uninstall_policy_url
          return @jamf_uninstall_policy_url if @jamf_uninstall_policy_url
          return unless uninstallable?

          pol_id = Jamf::Policy.valid_id jamf_uninstall_policy_name, cnx: jamf_cnx
          return unless pol_id

          @jamf_uninstall_policy_url = "#{jamf_gui_url}/policies.html?id=#{pol_id}&o=r"
        end

        # @return [String] the URL for the uninstall policy in Jamf Pro
        ######################
        def jamf_expire_policy_url
          return @jamf_expire_policy_url if @jamf_expire_policy_url
          return unless uninstallable?
          return unless expiration

          pol_id = Jamf::Policy.valid_id jamf_expire_policy_name, cnx: jamf_cnx
          return unless pol_id

          @jamf_expire_policy_url = "#{jamf_gui_url}/policies.html?id=#{pol_id}&o=r"
        end

      end # TitleJamfPro

    end # Mixins

  end # Server

end # Xolo
