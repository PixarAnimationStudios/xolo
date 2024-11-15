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
      # to define Version/Patch-related access to the Title Edit server
      #
      module VersionTedAccess

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

        # Create a new version in the title editor
        #
        # TODO: allow specification of version_order, probably by accepting a value
        # for the 'previous_version'?
        #
        # @return [void]
        ##########################
        def create_patch_in_ted
          progress "Title Editor: Creating Patch '#{version}' of SoftwareTitle '#{title}'", log: :info
          ted_title.patches.add_patch(
            version: version,
            minimumOperatingSystem: min_os,
            releaseDate: publish_date,
            reboot: reboot,
            standalone: standalone
          )
          new_patch = ted_title.patches.patch version

          set_patch_killapps
          set_patch_capabilites
          set_ted_patch_component_criteria ttl_obj: title_object

          self.ted_id_number = new_patch.patchId
        end

        # Update version/patch in the title editor directly.
        # This never called when updating versions via changes to
        # the title - that process calls the sub-methods directly.
        #
        # @return [void]
        ##########################
        def update_patch_in_ted
          progress "Title Editor: Updating Patch '#{version}' SoftwareTitle '#{title}'", log: :info

          Xolo::Server::Version::ATTRIBUTES.each do |attr, deets|
            ted_attribute = deets[:ted_attribute]
            next unless ted_attribute

            new_val = new_data_for_update[attr]
            old_val = send(attr)
            next if new_val == old_val

            # These changes happen in real time on the Title Editor server, no need to #save
            log_debug "Title Editor: Updating patch attribute '#{ted_attribute}': #{old_val} -> #{new_val}"
            ted_patch.send "#{ted_attribute}=", new_val
          end

          set_patch_killapps if changes_for_update[:killapps]
          set_patch_capabilites if changes_for_update[:min_os] || changes_for_update[:max_os]

          # This should not be needed here - its only affected by changes to the title, and
          # those are handled by the title object calling the same method
          #
          # set_ted_patch_component_criteria ttl_obj: title_object
        end

        # Set any killapps for this version in the title editor.
        #
        # @return [void]
        ##########################
        def set_patch_killapps
          # creating a new patch? Just use the current values
          if current_action == :creating
            kapps = killapps

          elsif current_action == :updating
            return unless changes_for_update[:killapps]

            kapps = changes_for_update[:killapps][:new]

            # delete the existing
            ted_patch.killApps.delete_all_killApps
          end
          return if kapps.pix_empty?

          # set the current values
          kapps.each do |ka_str|
            msg = "Title Editor: Setting killApp '#{ka_str}' for Patch '#{version}' of SoftwareTitle '#{title}'"
            progress msg, log: :info

            name, bundleid = ka_str.split(Xolo::SEMICOLON_SEP_RE)
            ted_patch.killApps.add_killApp(
              appName: name,
              bundleId: bundleid
            )
          end
        end

        # Set the capabilities for this version in the title editor.
        # This is a collection of criteria that define which computers
        # can install this version.
        #
        # At the very least we enforce the required minimum OS.
        # and optional maximim OS.
        #
        # TODO: Allow xadm to specify other capability criteria?
        #
        # @return [void]
        ##########################
        def set_patch_capabilites
          # creating a new patch? Just use the current values
          if current_action == :creating
            min = min_os
            max = max_os
            return unless min || max

          # updating an existing patch? Use the new values if they exist
          # noting that a nil new value for max_os means its being removed
          elsif current_action == :updating
            return unless changes_for_update&.key?(:max_os) || changes_for_update&.key?(:min_os)

            # min gets reset even if it didn't change and it can't be empty.
            min = changes_for_update.dig(:min_os, :new) || min_os

            # if max is changing and its nil, its being removed, so won't be re-added
            # if its not changing, keep the current value
            max = changes_for_update&.key?(:max_os) ? changes_for_update[:max_os][:new] : max_os

            # delete the existing criteria
            ted_patch.capabilities.delete_all_criteria
          else
            return
          end

          msg = "Title Editor: Setting min_os capability for Patch '#{version}' of SoftwareTitle '#{title}' to '#{min}'"
          progress msg, log: :info

          # min os - one is always required
          ted_patch.capabilities.add_criterion(
            name: 'Operating System Version',
            operator: 'greater than or equal',
            value: min
          )

          return unless max

          msg = "Title Editor: Setting max_os capability for Patch '#{version}' of SoftwareTitle '#{title}' to '#{max}'"
          progress msg, log: :debug

          ted_patch.capabilities.add_criterion(
            name: 'Operating System Version',
            operator: 'less than or equal',
            value: max
          )
        end

        # Set the component criteria for this version in the title editor.
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
        # This is a collection of criteria that define which computers
        # have this version installed
        #
        # @return [void]
        ##########################
        def set_ted_patch_component_criteria(app_name: nil, app_bundle_id: nil, ea_name: nil, ttl_obj: nil)
          if ttl_obj
            app_name, app_bundle_id, ea_name = get_patch_component_criteria_params(ttl_obj)

          elsif !((app_name && app_bundle_id) || ea_name)
            raise Xolo::MissingDataError, 'Must provide either ea_name or app_name & app_bundle_id, or ttl_obj'
          end

          type = ea_name ? 'Extension Attribute (version_script)' : 'App'
          msg = "Title Editor: Setting #{type}-based component criteria for Patch '#{version}' of SoftwareTitle '#{title}'"
          progress msg, log: :info

          # delete any already there and make a new one
          ted_patch.delete_component
          ted_patch.add_component name: title, version: version
          comp = ted_patch.component

          ea_name ? set_ea_component(comp, ea_name) : set_app_component(comp, app_name, app_bundle_id)

          enable_ted_patch
        end

        # get the param values for patch component criteria from the title object,
        # which may be setting them via an update
        #
        # @param ttl_obj [Xolo::Server::Title] the title object that may have the values
        # @return [Array] the values for the component criteria
        ##########################
        def get_patch_component_criteria_params(ttl_obj)
          app_name, app_bundle_id, ea_name = nil

          if ttl_obj.updating?
            if ttl_obj.changes_for_update.dig :app_name, :new
              app_name = ttl_obj.changes_for_update[:app_name][:new]
              app_bundle_id = ttl_obj.changes_for_update[:app_bundle_id][:new]
            else
              ea_name = ttl_obj.ted_ea_key
            end
          elsif ttl_obj.app_name
            app_name = ttl_obj.app_name
            app_bundle_id = ttl_obj.app_bundle_id
          else
            ea_name = ttl_obj.ted_ea_key
          end

          [app_name, app_bundle_id, ea_name]
        end

        # @return [void]
        ##############################
        def set_ea_component(comp, ea_name)
          comp.criteria.add_criterion(
            type: 'extensionAttribute',
            name: ea_name,
            operator: 'is',
            value: version
          )
        end

        # @return [void]
        ##############################
        def set_app_component(comp, app_name, app_bundle_id)
          comp.criteria.add_criterion(
            name: 'Application Title',
            operator: 'is',
            value: app_name
          )

          comp.criteria.add_criterion(
            name: 'Application Bundle ID',
            operator: 'is',
            value: app_bundle_id
          )

          comp.criteria.add_criterion(
            name: 'Application Version',
            operator: 'is',
            value: version
          )
        end

        # For a patch to be enabled in the Title Editor, it needs at least a component criterion
        # and one capability. Xolo enforces those when the patch is created, so from the title
        # editor's view it should be OK from the start.
        #
        # But Xolo can't really do anything with it until there's a Jamf Package object and
        # an uploaded installer.
        # So once we have those, this method is called to enable the patch.
        #
        # @param version [Xolo::Server::Version] the version who's patch to enable
        #
        # @return [void]
        ##############################
        def enable_ted_patch
          progress "Title Editor: (re)Enabling Patch '#{version} of SoftwareTitle '#{title}'", log: :info
          ted_patch.enable

          # Once we have an enabled patch, the title should also be enabled,
          # cuz everything else should be OK to go.
          # Do this thru the title object for logging
          # TODO: remove this once we know it isn't needed (happens in the title object itself)
          # title_object.enable_ted_title
        end

        # Delete from the title editor
        # @return [Integer] title editor id
        ###########################
        def delete_patch_from_ted
          patch_id = ted_title.patches.versions_to_patchIds[version]
          if patch_id
            progress "Title Editor: Deleting Patch '#{version}' of SoftwareTitle '#{title}'", log: :info
            ted_title.patches.delete_patch patch_id

          else
            log_debug "Title Editor: No id for Patch '#{version}' of SoftwareTitle '#{title}', nothing to delete"
          end

          ted_id_number
        rescue Windoo::NoSuchItemError
          ted_id_number
        end

        # @return [String] the URL for the Title Editor Web App page for this patch
        ###################################
        def ted_patch_url
          "https://#{Xolo::Server.config.ted_hostname}/patches/#{ted_id_number}"
        end

      end # VersionTedAccess

    end # Mixins

  end # Server

end # module Xolo
