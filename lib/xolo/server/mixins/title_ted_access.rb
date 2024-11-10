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
      # to define Title-related access to the Title Editor server
      #
      module TitleTedAccess

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
        # These are available directly in sinatra routes and views
        #
        ##############################
        ##############################

        # Create a new title in the title editor
        #
        # @return [void]
        ##########################
        def create_title_in_ted
          progress "Title Editor: Creating SoftwareTitle '#{title}'", log: :info
          @ted_title = Windoo::SoftwareTitle.create(
            id: title,
            name: display_name,
            publisher: publisher,
            appName: app_name,
            bundleId: app_bundle_id,
            currentVersion: Xolo::Server::Title::NEW_TITLE_CURRENT_VERSION,
            cnx: ted_cnx
          )

          create_ted_title_requirements

          self.ted_id_number = ted_title.softwareTitleId
        end

        # Create the requirements for a new title in the Title Editor
        # Either app-based or EA-based, depending on the data in the Xolo Title.
        #
        # Requirements are criteria indicating that this title (any version)
        # is installed on a client machine.
        #
        # If the Xolo Title has app_name and app_bundle_id defined,
        # they are used as the requirement criteria and the Patch component criteria.
        #
        # If the Xolo Title as a version_script defined, it returns
        # either an empty value, or the version installed on the client
        # It is added to the Title Editor title as the Ext Attr and used both as the
        # requirement criterion ( the value is not empty) and as a Patch Component
        # criterion for versions (the value contains the version).
        #
        # @return [void]
        def create_ted_title_requirements
          progress "Title Editor: Setting Requirements for new title '#{title}'", log: :debug

          # if we have app-based requirements, set them
          if app_name && app_bundle_id
            update_ted_title_app_requirements(
              req_app_name: app_name,
              req_app_bundle_id: app_bundle_id
            )
          else
            # if we have a version_script, set it
            update_ted_title_ea_requirements req_ea_script: version_script
          end
        end

        # Update title in the title editor
        #
        # @param new_data [Hash] The new data sent from xadm
        # @return [void]
        ##########################
        def update_title_in_ted
          return unless new_data_for_update

          progress "Title Editor: Updating SoftwareTitle '#{title}'", log: :info

          Xolo::Server::Title::ATTRIBUTES.each do |attr, deets|
            ted_attribute = deets[:ted_attribute]
            next unless ted_attribute

            new_val = new_data_for_update[attr]
            old_val = send(attr)

            # nothing to change if the values are the same
            next if new_val == old_val

            # These changes happen in real time on the Title Editor server
            change_msg = "Title Editor: Updating title attribute '#{ted_attribute}': #{old_val} -> #{new_val}"
            progress change_msg, log: :info

            ted_title.send "#{ted_attribute}=", new_val
          end

          update_ted_title_requirements if need_to_update_title_requirements?

          self.ted_id_number ||= ted_title.softwareTitleId
        end

        # Update the requirements in the TItle Editor title.
        #
        # If we switch from app-based to EA-based requirements, or vice versa,
        # all the patch components need to be updated.
        #
        #
        # @return [void]
        ######################
        def update_ted_title_requirements
          progress "Title Editor: Setting Requirements for title '#{title}'", log: :info

          req_app_name, req_app_bundle_id, req_ea_script = new_data_for_title_requirement

          # we are now using an app-based requirement, tho we might have been already
          if req_app_name && req_app_bundle_id
            update_ted_title_app_requirements(
              req_app_name: req_app_name,
              req_app_bundle_id: req_app_bundle_id
            )

          # now using EA-based requirement, tho we might have been already
          elsif req_ea_script

            # nothing to do if the new data shows ITEM_UPLOADED - it hasn't changed
            return if req_ea_script == Xolo::ITEM_UPLOADED

            # if we're already using an EA, but we are here, the EA script has
            # changed so just update it
            return if update_existing_ted_title_ea(req_ea_script: req_ea_script)

            # if we are here, we are createing the initial EA or changing from app-based to EA-based requirement
            update_ted_title_ea_requirements req_ea_script: req_ea_script

          else
            msg = 'No version_script, nor app_name & app_bundle_id - Cannot set Title Editor Title Requirements'
            log_error msg
            raise Xolo::MissingDataError, msg
          end
        end

        # @return [Boolean] Do we need to update the title requirements?
        #   True if the app name, bundle id, or version script have changed
        ###########################
        def need_to_update_title_requirements?
          need_to_update = false

          if new_data_for_update[:app_name] != app_name
            need_to_update = true
            msg = "Title Editor: App Name: #{app_name} -> #{new_data_for_update[:app_name]}"
            log_info msg
          end

          if new_data_for_update[:app_bundle_id] != app_bundle_id
            need_to_update = true
            msg = "Title Editor: Bundle ID: #{app_bundle_id} -> #{new_data_for_update[:app_bundle_id]}"
            log_info msg
          end

          if new_data_for_update[:version_script] != version_script
            need_to_update = true
            action = new_data_for_update[:version_script].pix_empty? ? 'Deleted' : 'Updated'
            msg = "Title Editor: Version Script: #{action}"
            log_info msg
          end

          need_to_update
        end

        # @return [Boolean] do we need to update the app-based requirements and patch components?
        ###########################
        def need_to_update_app_basaed_criteria?
          new_data_for_update[:app_name] != app_name || new_data_for_update[:app_bundle_id] != app_bundle_id
        end

        # @return [Array<String, nil>] three items, at least one of which will be nil
        #   - the new requirement app name,
        #   - the new requirement app bundle id
        #   - the new requirement EA script (may be Xolo::ITEM_UPLOADED, meaning no change)
        ###############################
        def new_data_for_title_requirement
          req_app_name = new_data_for_update ? new_data_for_update[:app_name] : app_name
          req_app_bundle_id = new_data_for_update ? new_data_for_update[:app_bundle_id] : app_bundle_id
          req_ea_script = new_data_for_update ? new_data_for_update[:version_script] : version_script
          [req_app_name, req_app_bundle_id, req_ea_script]
        end

        # Update the Title Editor Title Requirements with app name and bundle id.
        # these changes happen immediately on the server
        #
        # @param ted_title [Windoo::SoftwareTitle] the TEd title we are changing
        #
        # @return [void]
        ####################
        def update_ted_title_app_requirements(req_app_name:, req_app_bundle_id:)
          progress "Title Editor: Setting App-based Requirement Criteria for title '#{title}'", log: :debug

          # delete the current requirements, which might be EA based
          ted_title.requirements.delete_all_criteria

          ted_title.requirements.add_criterion(
            name: 'Application Title',
            operator: 'is',
            value: req_app_name
          )

          ted_title.requirements.add_criterion(
            name: 'Application Bundle ID',
            operator: 'is',
            value: req_app_bundle_id
          )

          return unless ted_title.extensionAttribute

          progress "Title Editor: Deleting unused Extension Attribute for title '#{title}'", log: :debug
          ted_title.delete_extensionAttribute
        end

        # if we are already using a ted Title EA, but it has changed,
        # update it and return true
        # @return [Boolean] do have have (and did we update) an existing TedEA?
        #########################
        def update_existing_ted_title_ea(req_ea_script:)
          if ted_title.requirements.first&.type == 'extensionAttribute'
            ted_title.extensionAttribute.script = req_ea_script
            @need_to_accept_xolo_ea_in_jamf = true
          else
            false
          end
        end

        # Update the Title Editor Title EA  and requireents
        # with the current version_script
        #
        # these changes happen immediately on the server
        #
        # @param ea_script [String] the code of the script.
        #
        # @return [void]
        ####################
        def update_ted_title_ea_requirements(req_ea_script:)
          # if we are here, we are creating the requirement for the first time,
          # or changing from app-based to EA-based requirement
          # so delete the current app-based requirements, if any
          ted_title.requirements.delete_all_criteria

          msg = "Title Editor: Setting ExtensionAttribute version_script and Requirement Criteria for title '#{title}'"
          progress msg, log: :debug

          # delete and recreate the EA
          ted_title.delete_extensionAttribute

          ted_title.add_extensionAttribute(
            key: ted_ea_key,
            displayName: ted_ea_key,
            script: req_ea_script
          )

          # add a requirement criterion using the EA
          # Any value in the EA means the title is installed
          # (the value will be the version that is installed)
          ted_title.requirements.add_criterion(
            type: 'extensionAttribute',
            name: ted_ea_key,
            operator: 'matches regex',
            value: '.+'
          )

          # Accept it... when?
          @need_to_accept_xolo_ea_in_jamf = true
          # accept_xolo_ea_in_jamf
        end

        # Update the patch compenent criteria for a given
        # Version Object to match our title requirement critera
        # and ensure the patch is enabled in Ted.
        #
        # @param vers_obj [Xolo::Server::Version] the patch/version we are updating
        #
        # @return [void]
        def update_ted_patch_component_for_version(vers_obj)
          vers_obj.update_patch_component title_obj: self

          progress "Title Editor: Enabling Patch '#{vers_obj.version} of SoftwareTitle '#{title}'", log: :debug
          # loop until the enablement goes thru
          # TODO: make this not infinite
          loop do
            sleep 5
            vers_obj.ted_patch(refresh: true).enable
            break
          rescue StandardError => e
            log_debug "Title Editor: Caught #{e.class} while Looping while re-enabling  Patch '#{vers_obj.version} of SoftwareTitle '#{title}': #{e}"
            nil
          end
        end

        # For a Title to be enabled in the Title Editor, it needs at least a requirement criterion
        # and one enabled patch. Xolo enforces the requirement when the title is created, so from
        # the title editor's view it should be OK as soon as there's an enabled patch.
        #
        # So once we have that, this method is called to enable the title.
        #
        # @param title [Xolo::Server::Title] the Title to enable in the Title Editor
        #
        # @return [void]
        ##############################
        def enable_ted_title
          progress "Title Editor: Enabling SoftwareTitle '#{title}'", log: :debug
          ted_title.enable
        end

        # Re-enable the title in ted after updating any patches
        # @return [void]
        ##############################
        def reenable_ted_title
          # re-enable the title itself, we should have at least one enabled version
          progress "Title Editor: Re-Enabling SoftwareTitle '#{title}'", log: :debug
          # loop until the enablement goes thru
          # TODO: make this non-infinite
          loop do
            sleep 5
            ted_title(refresh: true).enable
            break
          rescue Windoo::MissingDataError
            log_debug "Title Editor: Looping while re-enabling SoftwareTitle '#{title}'"
            nil
          end
        end

        # Delete from the title editor
        # @return [Integer] title editor id number
        ###########################
        def delete_title_from_ted
          progress "Title Editor: Deleting SoftwareTitle '#{title}'", log: :info

          ted_title.delete
        rescue Windoo::NoSuchItemError
          ted_id_number
        end

        # @return [String] the URL for the title in the Title Editor
        #####################
        def ted_title_url
          "https://#{Xolo::Server.config.ted_hostname}/softwaretitles/#{ted_id_number}"
        end

      end # TitleEditorTitle

    end # Mixins

  end # Server

end # module Xolo
