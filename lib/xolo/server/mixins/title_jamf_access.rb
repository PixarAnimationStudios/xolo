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
          update_normal_ea_in_jamf
          update_installed_smart_group_in_jamf

          # Create the static group that will contain computers
          # where this title is 'frozen'
          # To start with it has no members, but will be used in scope exclusions
          Jamf::ComputerGroup.create(
            name: jamf_frozen_group_name,
            type: :static,
            cnx: jamf_cnx
          ).save
        end

        # Apply any changes to Jamf as needed
        # Mostly this just sets flags indicating what needs to be updated in the
        # various version-related things in jamf - policies, self service, etc.
        #
        # @return [void]
        #########################
        def update_title_in_jamf
          # do we have a version_script? if so we maintain a 'normal' EA
          # this has to happen before updating the installed_smart_group
          update_normal_ea_in_jamf if version_script

          # this smart group might use the normal-EA or might use app data
          update_installed_smart_group_in_jamf

          # If we don't use a version script anymore, delete the normal EA
          # this has to happen after updating the installed_smart_group
          delete_normal_ea_from_jamf unless version_script

          unless jamf_ted_title_active?
            log_debug "Jamf: Title '#{display_name}' (#{title}) is not yet active to Jamf, nothing to update in versions."
            return
          end
          # Set all these values so they'll be applied to all versions when we update them next.

          @need_to_update_ssvc = new_data_for_update[:self_service] != self_service
          @need_to_update_ssvc_category = new_data_for_update[:self_service_category] != self_service_category

          # prob not needed, since the upload is a separate process from the title update
          @need_to_update_ssvc_icon = new_data_for_update[:self_service_icon] && new_data_for_update[:self_service_icon] != Xolo::ITEM_UPLOADED

          # Excluded, Pilot, or Release groups changed at the
          # title level, make note to update the scope of all version-specific policies and patch policies
          # when we loop thru the versions
          @need_to_update_pilot_groups = new_data_for_update[:pilot_groups].to_a.sort != pilot_groups.to_a.sort
          @need_to_update_release_groups = new_data_for_update[:release_groups].to_a.sort != release_groups.to_a.sort
          @need_to_update_excluded_groups = new_data_for_update[:excluded_groups].to_a.sort != excluded_groups.to_a.sort

          # TODO: EVENTUALLY if needed, send out a new xolo-title-data pkg to all clients
          # e.g. if expiration data changes
        end

        # Create or update the smartgroup in jamf that contains all macs
        # with any version of this title installed.
        #
        # @return [void]
        #####################################
        def update_installed_smart_group_in_jamf
          grp = jamf_installed_smart_group
          grp.criteria = Jamf::Criteriable::Criteria.new(jamf_installed_smart_group_criteria)
          grp.save
        end

        # The smartgroup in jamf that contains all macs
        # with any version of this title installed.
        #
        # @return [Jamf::ComputerGroup]
        #####################################
        def jamf_installed_smart_group
          if Jamf::ComputerGroup.all_names(cnx: jamf_cnx).include? jamf_installed_smart_group_name
            progress "Updating smart group '#{jamf_installed_smart_group_name}'", log: :debug

            Jamf::ComputerGroup.fetch name: jamf_installed_smart_group_name, cnx: jamf_cnx
          else
            progress "Creating smart group '#{jamf_installed_smart_group_name}'", log: :debug
            Jamf::ComputerGroup.create(
              name: jamf_installed_smart_group_name,
              type: :smart,
              cnx: jamf_cnx
            )
          end
        end

        # The criteria for the smart group in Jamf that contains all Macs
        # with any version of this title installed
        #
        # @return [Array<Jamf::Criteriable::Criterion>]
        ###################################
        def jamf_installed_smart_group_criteria
          if app_bundle_id
            [
              Jamf::Criteriable::Criterion.new(
                and_or: :and,
                name: 'Application Title',
                search_type: 'is',
                value: app_name
              ),

              Jamf::Criteriable::Criterion.new(
                and_or: :and,
                name: 'Application Bundle ID',
                search_type: 'is',
                value: app_bundle_id
              )
            ]
          else
            [
              Jamf::Criteriable::Criterion.new(
                and_or: :and,
                name: jamf_ea_name,
                search_type: 'is not',
                value: Xolo::BLANK
              )
            ]
          end
        end

        # Create or update a 'normal' EA that matches the Patch EA for this title,
        # so that it can be used in smart groups and adv. searches.
        # (Patch EAs aren't available for use in smart group critera)
        #
        # @return [void]
        ################################
        def update_normal_ea_in_jamf
          scr = version_script_contents
          return unless scr

          ea =
            if Jamf::ComputerExtensionAttribute.all_names(cnx: jamf_cnx).include? jamf_ea_name
              progress "Updating regular extension attribute '#{jamf_ea_name}' for use in smart group", log: :debug

              Jamf::ComputerExtensionAttribute.fetch(name: jamf_ea_name, cnx: jamf_cnx)
            else
              progress "Creating regular extension attribute '#{jamf_ea_name}' for use in smart group", log: :debug

              Jamf::ComputerExtensionAttribute.create(
                name: jamf_ea_name,
                description: "The version of xolo title '#{title}' installed on the machine",
                data_type: :string,
                enabled: true,
                cnx: jamf_cnx
              )
            end
          ea.script = scr
          ea.save
        end

        # @return [Jamf::PatchSource] The Jamf Patch Source that is connected to the Title Editor
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
        # it has at least one requirement, and an enabled patch/version.
        #
        # Xolo should have enabled it in the Title editor before we
        # reach this point.
        #
        ##########################
        def activate_patch_title_in_jamf
          if jamf_ted_title_active?
            log_debug "Jamf: Title '#{display_name}' (#{title}) is already active to Jamf"
            return
          end

          # wait up to 30 seconds for the title to become available
          counter = 0
          until jamf_ted_title_available? || counter == 6
            log_debug "Jamf: Waiting for title '#{display_name}' (#{title}) to become available from the Title Editor"
            sleep 5
            counter += 1
          end

          unless jamf_ted_title_available?
            msg = "Jamf: Title '#{title}' is not yet available to Jamf. Make sure it has at least one version enabled in the Title Editor"
            log_error msg
            raise Xolo::NoSuchItemError, msg
          end

          title_in_jamf_patch =
            Jamf::PatchTitle.create(
              name: display_name,
              source: Xolo::Server.config.ted_patch_source,
              name_id: title,
              category: Xolo::Server::JAMF_XOLO_CATEGORY,
              cnx: jamf_cnx
            )

          title_in_jamf_patch.save

          msg = "Jamf: Activated Patch Title '#{display_name}' (#{title}) from the Title Editor Patch Source '#{Xolo::Server.config.ted_patch_source}'"
          progress msg, log: :info

          ea_matches = jamf_patch_ea_matches_version_script?
          return if ea_matches.nil?

          # only call this if we expect jamf to tell us to accept the EA
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
        # TODO: make this a config setting, users should be able to require manual acceptance.
        # Also - handle it not being accepted yet.
        #
        # TODO: when this is implemented in ruby-jss, use the implementation
        #
        # NOTE: PATCHing the ea of the title requires CRUD privs for computer ext attrs
        #
        # @return [void]
        ############################
        def accept_xolo_patch_ea_in_jamf
          # return with warning if we aren't auto-accepting
          unless Xolo::Server.config.jamf_auto_accept_xolo_eas
            progress "Jamf: IMPORTANT: the version-script ExtAttr for this title '#{ted_ea_key}' must be accepted manually in Jamf Pro",
                     log: :info
            return
          end

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

          if jamf_patch_ea_needs_acceptance?
            jamf_cnx.jp_patch "v2/patch-software-title-configurations/#{jamf_title_id}", patchdata
            progress "Jamf: Auto-accepted use of version-script ExtensionAttribute '#{ted_ea_key}'", log: :debug
            return
          end

          auto_accept_patch_ea_in_thread patchdata
        end

        #####################
        def auto_accept_patch_ea_in_thread(patchdata)
          # don't do this if there's already one running for this instance
          if @auto_accept_ea_thread&.alive?
            log_debug "Jamf: auto_accept_ea_thread already running. Caller: #{caller_locations.first}"
            return
          end

          progress "Jamf: version-script ExtAttr for this title '#{ted_ea_key}' will be auto-accepted when Jamf sees the changes in the Title Editor"

          @auto_accept_ea_thread = Thread.new do
            log_debug "Jamf: Starting auto_accept_ea_thread for #{title}"
            start_time = Time.now
            max_time = start_time + 3600
            start_time = start_time.strftime '%F %T'
            did_it = false

            while Time.now < max_time
              sleep 30
              log_debug "Jamf: checking for expected (re)acceptance of version-script ExtensionAttribute '#{ted_ea_key}' since #{start_time}"
              next unless jamf_patch_ea_needs_acceptance?

              jamf_cnx.jp_patch "v2/patch-software-title-configurations/#{jamf_title_id}", patchdata
              log_info "Jamf: Auto-accepted use of version-script ExtensionAttribute '#{ted_ea_key}'"
              did_it = true
              break
            end # while

            unless did_it
              log_error "Jamf: Expected to (re)accept version-script ExtensionAttribute '#{ted_ea_key}', but Jamf hasn't seen the change in over an hour. Please investigate.",
                        alert: true
            end
          end # thread
        end

        # @return [Boolean] does the Jamf Title currently need its EA to be accepted?
        #################################
        def jamf_patch_ea_needs_acceptance?
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
        # vs the Jamf EA.
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

          # the script in Jamf
          jea_data = jamf_patch_ea_data
          j_script = (Base64.decode64(jea_data[:scriptContents]) if jea_data).to_s

          # does jamf's script match ours?
          our_version_script.chomp == j_script.chomp
        end

        # The version_script as a Jamf Extension Attribute,
        # once the title as been activated in Jamf.
        #
        # This is a hash of data returned from the JP API endpoint:
        #    "v2/patch-software-title-configurations/#{jamf_title_id}/extension-attributes"
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
          jid = jamf_title_id
          return unless jid

          jamf_cnx.jp_get("v2/patch-software-title-configurations/#{jid}/extension-attributes").first
        end

        # The titles active in Jamf Patch Management from the Title Editor
        # This takes into account that other Patch Sources may have titles with the
        # same 'name_id' (the xolo 'title')
        #
        # @return [Array<String>] The xolo titles that are active in Jamf Patch Management
        ########################
        def jamf_active_ted_titles
          Jamf::PatchTitle.all(cnx: jamf_cnx).select do |t|
            t[:source_id] == jamf_ted_patch_source.id
          end.map { |t| t[:name_id] }
        end

        # @return [Boolean] Is this xolo title currently active in Jamf?
        ########################
        def jamf_ted_title_active?
          jamf_active_ted_titles.include? title
        end

        # @param refresh [Boolean] re-fetch the patch title from Jamf?
        # @return [Jamf::PatchTitle] The Jamf Patch Title for this Xolo Title
        ########################
        def jamf_patch_title(refresh: false)
          @jamf_patch_title = nil if refresh
          return @jamf_patch_title if @jamf_patch_title

          unless jamf_ted_title_active?
            msg = "Jamf: Title '#{title}' is not activated in Jamf Patch Management"
            log_error msg
            raise Xolo::NoSuchItemError, msg
          end

          @jamf_patch_title =
            Jamf::PatchTitle.fetch(
              name_id: title,
              source_id: jamf_ted_patch_source.id,
              cnx: jamf_cnx
            )
        end

        # @return [Integer] The Jamf ID of this title, if it is active in Jamf
        ##################################
        def jamf_title_id
          @jamf_title_id ||= Jamf::PatchTitle.map_all(:id, to: :name_id, cnx: jamf_cnx).invert[title]
        end

        # Delete an entire title from Jamf Pro
        ########################
        def delete_title_from_jamf
          delete_installed_smart_group_from_jamf
          delete_normal_ea_from_jamf
          delete_patch_title_from_jamf
          delete_frozen_group_from_jamf
        end

        # Delete the 'installed' smart group
        # @return [void]
        ######################################
        def delete_installed_smart_group_from_jamf
          return unless Jamf::ComputerGroup.all_names(cnx: jamf_cnx).include? jamf_installed_smart_group_name

          progress "Deleting smart group '#{jamf_installed_smart_group_name}'", log: :info
          Jamf::ComputerGroup.fetch(name: jamf_installed_smart_group_name, cnx: jamf_cnx).delete
        end

        # Delete the 'frozen' static group
        # @return [void]
        ######################################
        def delete_frozen_group_from_jamf
          return unless Jamf::ComputerGroup.all_names(cnx: jamf_cnx).include? jamf_frozen_group_name

          progress "Deleting static group '#{jamf_frozen_group_name}'", log: :info
          Jamf::ComputerGroup.fetch(name: jamf_frozen_group_name, cnx: jamf_cnx).delete
        end

        # Delete the 'normal' computer ext attr matching the Patch EA
        # @return [void]
        ######################################
        def delete_normal_ea_from_jamf
          return unless Jamf::ComputerExtensionAttribute.all_names(cnx: jamf_cnx).include? jamf_ea_name

          progress "Deleting regular extension attribute '#{jamf_ea_name}'", log: :info
          Jamf::ComputerExtensionAttribute.fetch(name: jamf_ea_name, cnx: jamf_cnx).delete
        end

        # Delete the patch title
        ##############################
        def delete_patch_title_from_jamf
          return unless jamf_ted_title_active?

          progress "Jamf: Deleting (unsubscribing) title '#{display_name}'  (#{title}}) in Jamf Patch Management",
                   log: :info

          # NOTE: jamf api user must have 'delete computer ext. attribs' permmissions
          jamf_patch_title.delete
        end

        # Freeze or thaw an array of computers for a title
        #
        # @param action [Symbol] :freeze or :thaw
        #
        # @param computers [Array<String>, String] The computer name[s] to freeze or thaw. To thaw
        #   all computers pass Xolo::TARGET_ALL
        #
        # @return [Hash] Keys are computer names, values are Xolo::OK or an error message
        #################################
        def freeze_or_thaw_computers(action:, computers:)
          unless Jamf::ComputerGroup.all_names(cnx: jamf_cnx).include? jamf_frozen_group_name
            halt 404, { status: 404, error: "No Jamf Computer Group '#{jamf_frozen_group_name}'" }
          end

          # convert to an array if it's a single string
          computers = [computers].flatten

          grp = Jamf::ComputerGroup.fetch name: jamf_frozen_group_name, cnx: jamf_cnx

          result =
            if action == :thaw
              thaw_computers(computers: computers, grp: grp)
            elsif action == :freeze
              freeze_computers(computers: computers, grp: grp)
            else
              raise "Unknown action '#{action}', must be :freeze or :thaw"
            end # if action ==

          log_debug "grp: #{grp.member_names}"

          grp.save

          result
        end

        # thaw some computers
        # see #freeze_or_thaw_computers
        ##############
        def thaw_computers(computers:, grp:)
          result = {}
          if computers.include? Xolo::TARGET_ALL
            log_info "Thawing all computers for title: '#{title}'"
            grp.clear
            result[Xolo::TARGET_ALL] = Xolo::OK

          else
            grp_members = grp.member_names
            computers.each do |comp|
              if grp_members.include? comp
                grp.remove_member comp
                log_info "Thawed computer '#{comp}' for title '#{title}'"
                result[comp] = Xolo::OK
              else
                log_debug "Cannot thaw computer '#{comp}' for title '#{title}', not frozen"
                result[comp] = "#{Xolo::ERROR}: Not frozen"
              end
            end
          end # if computers.include?
          result
        end

        # freeze some computers
        # see #freeze_or_thaw_computers
        ##############
        def freeze_computers(computers:, grp:)
          result = {}
          comp_names = Jamf::Computer.all_names cnx: jamf_cnx
          grp_members = grp.member_names

          computers.each do |comp|
            if grp_members.include? comp
              log_info "Not freezing computer '#{comp}' for title '#{title}', already frozen"
              result[comp] = "#{Xolo::ERROR}: Already frozen"
            elsif comp_names.include? comp
              log_info "Freezing computer '#{comp}' for title '#{title}'"
              grp.add_member comp
              result[comp] = Xolo::OK
            else
              log_debug "Cannot freeze computer '#{comp}' for title '#{title}', no such computer"
              result[comp] = "#{Xolo::ERROR}: No computer with that name"
            end # if comp_names.include
          end # computers.each
          result
        end

      end # TitleJamfPro

    end # Mixins

  end # Server

end # Xolo
