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

        # @return [Windoo::SoftwareTitle] The Windoo::SoftwareTitle object that represents
        #   this title in the title editor
        #############################
        def ted_title(refresh: false)
          @ted_title = nil if refresh
          return @ted_title if @ted_title

          @ted_title =
            if Windoo::SoftwareTitle.all_ids(cnx: ted_cnx).include? title
              Windoo::SoftwareTitle.fetch id: title, cnx: ted_cnx
            else
              return if deleting?

              create_title_in_ted
            end

          @ted_title
        end

        # Create this title in the title editor
        #
        # @return [Windoo::SoftwareTitle]
        ##########################
        def create_title_in_ted
          # delete an old one if its there
          ted_title&.delete if Windoo::SoftwareTitle.all_ids(cnx: ted_cnx).include? title

          new_title = Windoo::SoftwareTitle.create(
            id: title,
            name: display_name,
            publisher: publisher,
            appName: app_name,
            bundleId: app_bundle_id,
            currentVersion: Xolo::Server::Title::NEW_TITLE_CURRENT_VERSION,
            cnx: ted_cnx
          )

          progress "Title Editor: Creating SoftwareTitle '#{title}'", log: :info
          create_ted_title_requirements

          self.ted_id_number = ted_title.softwareTitleId
          @ted_title = new_title
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
        # requirement criterion (the value is not empty) and as a Patch Component
        # criterion for versions (the value contains the version).
        #
        # @return [void]
        def create_ted_title_requirements
          # if we have app-based requirements, set them
          if app_name && app_bundle_id
            set_ted_title_requirement app_name: app_name, app_bundle_id: app_bundle_id
          elsif version_script
            # if we have a version_script, set it
            create_ted_ea version_script
            set_ted_title_requirement ea_name: ted_ea_key
          else
            raise Xolo::MissingDataError,
                  'Cannot create Title Editor Title Requirements without app_name & app_bundle_id, or version_script'
          end
        end

        # Update title in the title editor
        #
        # @param new_data [Hash] The new data sent from xadm
        # @return [void]
        ##########################
        def update_title_in_ted
          return unless changes_for_update

          unless any_ted_changes?
            progress "Title Editor: No changes to make for SoftwareTitle '#{title}'", log: :info
            return
          end

          progress "Title Editor: Updating SoftwareTitle '#{title}'", log: :info

          # loop through the attributes that are in the Title Editor
          Xolo::Server::Title::ATTRIBUTES.each do |attr, deets|
            ted_attribute = deets[:ted_attribute]
            next unless ted_attribute
            next unless changes_for_update&.key? attr

            new_val = changes_for_update[attr][:new]
            old_val = changes_for_update[attr][:old]

            progress "Title Editor: Updating title attribute '#{ted_attribute}': #{old_val} -> #{new_val}", log: :info

            ted_title.send "#{ted_attribute}=", new_val
          end # Xolo::Server::Title::ATTRIBUTES.each

          # This will also apply the changes to all patch component criteria
          apply_requirement_changes

          # mucking with the patches often disables the title, make sure its enabled.
          enable_ted_title

          self.ted_id_number ||= ted_title.softwareTitleId
        end

        # Apply changes to the Title Editor Title Requirements
        # and patch component criteria for all versions
        #
        # @return [void]
        ##############################
        def apply_requirement_changes
          req_change = requirement_change
          return unless req_change

          new_app_name = changes_for_update[:app_name][:new]
          new_app_bundle_id = changes_for_update[:app_bundle_id][:new]
          new_ea_script = changes_for_update[:version_script][:new]

          case req_change
          when :app_to_ea
            # create the ea
            create_ted_ea new_ea_script
            # set the requirement to use the ea
            set_ted_title_requirement ea_name: ted_ea_key
            # for all versions, update the patch compotent criteria to use the ea
            set_ted_patch_component_criteria_after_update ea_name: ted_ea_key

          when :ea_to_app
            # set the requirement to use the app data
            set_ted_title_requirement app_name: new_app_name, app_bundle_id: new_app_bundle_id
            # for all versions, update the patch compotent criteria to use the app data
            set_ted_patch_component_criteria_after_update app_name: new_app_name, app_bundle_id: new_app_bundle_id
            # delete the ea
            delete_ted_ea

          when :update_app
            # set the requirement to use the new app data
            set_ted_title_requirement app_name: new_app_name, app_bundle_id: new_app_bundle_id
            # for all versions, update the patch compotent criteria to use the new app data
            set_ted_patch_component_criteria_after_update app_name: new_app_name, app_bundle_id: new_app_bundle_id

          when :update_ea
            # update the ea script
            update_ted_ea new_ea_script

          end
        end

        # @return [Boolean] are there any changes to make in the Title Editor?
        ##########################
        def any_ted_changes?
          ted_attrs = Xolo::Server::Title::ATTRIBUTES.select { |_attr, deets| deets[:ted_attribute] }.keys
          # version scripts are handled differently and are not marked as
          # ted_attributes, so we need to add it here
          ted_attrs << :version_script

          (changes_for_update.keys & ted_attrs).empty? ? false : true
        end

        # Are we changing any requirements, and if so, how?
        # @return [Symbol] :app_to_ea, :ea_to_app, :update_app, :update_ea
        ######################
        def requirement_change
          # we have to change the version script, but are we just updating it,
          # or switching to it from app data?
          if changes_for_update[:version_script]

            # if we have no old value, we are switching to ea, from app data
            if changes_for_update[:version_script][:old].pix_empty?
              :app_to_ea

            # if we have no new value, we are switching from ea, to app data
            elsif changes_for_update[:version_script][:new].pix_empty?
              :ea_to_app

            # if we are here, we have both, so we are just updating the ea script
            else
              :update_ea
            end

          # if we are here, we aren't changing the ea at all, but we might be
          # updating the app data
          elsif changes_for_update[:app_name] || changes_for_update[:app_bundle_id]
            :update_app

            # and if none of that is true, we'll return nil
          end
        end

        # @return [String] The key and display name of a version script stored
        #   in the title editor as the ExtAttr for this title
        #####################
        def ted_ea_key
          @ted_ea_key ||= self.class.ted_ea_key title
        end

        # Create the EA in the Title Editor
        #
        # @return [void]
        ##############################
        def create_ted_ea(script)
          # delete and recreate the EA
          progress "Title Editor: Creating Extension Attribute from version_script for title '#{title}'", log: :info

          ted_title.delete_extensionAttribute

          ted_title.add_extensionAttribute(
            key: ted_ea_key,
            displayName: ted_ea_key,
            script: script
          )
          @need_to_accept_xolo_ea_in_jamf = true
        end

        # Update the EA in the Title Editor
        # the only thing we update is the script
        #
        # @return [void]
        ##############################
        def update_ted_ea(script)
          progress "Title Editor: Updating Extension Attribute from version_script for title '#{title}'", log: :info

          ted_title.extensionAttribute.script = script
          @need_to_accept_xolo_ea_in_jamf = true
        end

        # Delete the extension attribute from the title editor
        # @return [void]
        ##############################
        def delete_ted_ea
          progress "Title Editor: Deleting Extension Attribute for title '#{title}'", log: :info
          ted_title.delete_extensionAttribute
        end

        # Set the requirements for a title in the Title Editor
        #
        # If the title has an EA script, it is used as the requirement criterion
        # (the EA should already be created in the Title Editor)
        #
        # If the title has app_name and app_bundle_id, they are used as the requirement criteria
        #
        # @param app_name [String] the name of the app to use in app-based requirements,
        #   must be used with app_bundle_id, cannot be used with ea_name
        #
        # @param app_bundle_id [String] the bundle id of the app to use in app-based requirements
        #   must be used with app_name, cannot be used with ea_name
        #
        # @param ea_name [String] the name of the EA to use in EA-based requirements (the ted_ea_key)
        #   Cannot be used with app_name or app_bundle_id
        #
        # @return [void]
        ##############################
        def set_ted_title_requirement(app_name: nil, app_bundle_id: nil, ea_name: nil)
          unless (app_name && app_bundle_id) || ea_name
            raise Xolo::MissingDataError, 'Must provide either ea_name or app_name & app_bundle_id'
          end

          type = ea_name ? 'Extension Attribute (version_script)' : 'App'

          progress "Title Editor: Setting #{type}-based Requirement for SoftwareTitle '#{title}'", log: :info

          # delete any already there
          ted_title.requirements.delete_all_criteria

          ea_name ? set_ea_requirement(ea_name) : set_app_requirement(app_name, app_bundle_id)
        end

        # @return [String] the progress/log message
        ##############################
        def set_ea_requirement(ea_name)
          # add criteria for the ea name
          ted_title.requirements.add_criterion(
            type: 'extensionAttribute',
            name: ea_name,
            operator: 'is not',
            value: Xolo::BLANK
          )
        end

        # @return [String] the progress/log message
        ##############################
        def set_app_requirement(app_name, app_bundle_id)
          # add criteria for the app name and bundle id.
          ted_title.requirements.add_criterion(
            name: 'Application Title',
            operator: 'is',
            value: app_name
          )

          ted_title.requirements.add_criterion(
            name: 'Application Bundle ID',
            operator: 'is',
            value: app_bundle_id
          )
        end

        # update the patch compotent criteria for all versions
        # to match changes in the title requirements
        #
        # @return [void]
        ##############################
        def set_ted_patch_component_criteria_after_update(app_name: nil, app_bundle_id: nil, ea_name: nil)
          version_objects.each do |vers_obj|
            vers_obj.set_ted_patch_component_criteria(
              app_name: app_name,
              app_bundle_id: app_bundle_id,
              ea_name: ea_name
            )
          end
        end

        # Enable the title in the title editor when at least one patch is enabled
        #
        # Re-enable the title in ted after updating any patches
        #
        # @return [void]
        ##############################
        def enable_ted_title
          # Nothing to re-enabled unless we have at least one enabled patch
          return unless ted_title.patches.to_a.any?(&:enabled?)

          # re-enable the title itself, we should have at least one enabled version
          progress "Title Editor: (Re-)Enabling SoftwareTitle '#{title}'", log: :debug

          # loop until the enablement goes thru
          breaktime = Time.now + Xolo::Server::Constants::MAX_JAMF_WAIT_FOR_TITLE_EDITOR
          loop do
            if Time.now > breaktime
              raise Xolo::TimeoutError, "Title Editor: Timed out waiting for SoftwareTitle '#{title}' to enable"
            end

            sleep 5
            ted_title(refresh: true).enable
            break
          rescue Windoo::MissingDataError
            log_debug "Title Editor: Looping up to #{Xolo::Server::Constants::MAX_JAMF_WAIT_FOR_TITLE_EDITOR} secs while re-enabling SoftwareTitle '#{title}'"
            nil
          end
        end

        # Delete from the title editor
        # @return [Integer] title editor id number
        ###########################
        def delete_title_from_ted
          progress "Title Editor: Deleting SoftwareTitle '#{title}'", log: :info

          ted_title&.delete if Windoo::SoftwareTitle.all_ids(cnx: ted_cnx).include? title
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
