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
      module VersionTitleEditor

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

          update_patch_killapps
          update_patch_capabilites
          update_patch_component

          self.ted_id_number = new_patch.patchId
        end

        # Update version/patch in the title editor
        #
        # @return [void]
        ##########################
        def update_patch_in_ted
          log_info "Title Editor: Updating Patch '#{version}' SoftwareTitle '#{title}'"

          Xolo::Server::Version::ATTRIBUTES.each do |attr, deets|
            ted_attribute = deets[:ted_attribute]
            next unless ted_attribute

            new_val = @new_data_for_update[attr]
            old_val = send(attr)
            next if new_val == old_val

            # These changes happen in real time on the Title Editor server, no need to #save
            log_debug "Title Editor: Updating patch attribute '#{ted_attribute}': #{old_val} -> #{new_val}"
            ted_patch.send "#{ted_attribute}=", new_val
          end

          update_patch_killapps
          update_patch_capabilites
          update_patch_component

          self.ted_id_number = ted_patch.patchId
        end

        # Update any killapps for this version in the title editor.
        #
        # @return [void]
        ##########################
        def update_patch_killapps
          kapps = @new_data_for_update ? @new_data_for_update[:killapps] : killapps
          return unless kapps

          # delete the existing
          progress "Title Editor: updating killApps for Patch '#{version}' of SoftwareTitle '#{title}'", log: :debug
          ted_patch.killApps.delete_all_killApps

          # Add the current ones back in
          kapps.each do |ka_str|
            name, bundleid = ka_str.split(Xolo::SEMICOLON_SEP_RE)
            log_debug "Title Editor: Setting killApp '#{ka_str}' for Patch '#{version}' of SoftwareTitle '#{title}'"

            ted_patch.killApps.add_killApp(
              appName: name,
              bundleId: bundleid
            )
          end
        end

        # Update the capabilities for this version in the title editor.
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
        def update_patch_capabilites
          progress "Title Editor: updating capabilities for Patch '#{version}' of SoftwareTitle '#{title}'",
                   log: :debug

          # delete the existing
          ted_patch.capabilities.delete_all_criteria

          # min os
          min = @new_data_for_update ? @new_data_for_update[:min_os] : min_os

          progress "Title Editor: setting min_os capability for Patch '#{version}' of SoftwareTitle '#{title}'",
                   log: :debug

          ted_patch.capabilities.add_criterion(
            name: 'Operating System Version',
            operator: 'greater than or equal',
            value: min
          )

          # max os
          max = @new_data_for_update ? @new_data_for_update[:max_os] : max_os

          return unless max

          progress "Title Editor: setting max_os capability for Patch '#{version}' of SoftwareTitle '#{title}'",
                   log: :debug
          ted_patch.capabilities.add_criterion(
            name: 'Operating System Version',
            operator: 'less than or equal',
            value: max
          )
        end

        # Update the component criteria for this version in the title editor.
        #
        # This is a collection of criteria that define which computers
        # have this version installed
        #
        # TODO: allow xadm to define more complex critera?
        # TODO: If title switches between version script and app info, all patch components must be updated
        #
        # @param title [Xolo::Server::Title] an existing title object for this version, so  when the title
        #   loops thru calling this method, we don't keep re-instantiating it
        #
        # @return [void]
        ##########################
        def update_patch_component(title_obj: nil)
          log_debug "Title Editor: updating component criteria for Patch '#{version}' of SoftwareTitle '#{title}'"

          # delete the existing component, and its criteria
          ted_patch.delete_component

          # create a new one
          ted_patch.add_component name: title, version: version
          comp = ted_patch.component

          # if we weren't passed one, instantiate it now
          title_obj ||= title_object

          # Are we using the 'version_script' (aka the EA for the title)
          if title_obj.version_script
            update_ea_component(comp, title_obj)

          # If not, we are using the app name and bundle ID
          # and version
          else
            update_app_component(comp, title_obj)
          end
        end

        # @return [void]
        ##############################
        def update_ea_component(comp, title_obj)
          progress "Title Editor: setting EA-based component criteria for Patch '#{version}' of SoftwareTitle '#{title}'",
                   log: :debug

          comp.criteria.add_criterion(
            type: 'extensionAttribute',
            name: title_obj.ted_ea_key,
            operator: 'is',
            value: version
          )
        end

        # @return [void]
        ##############################
        def update_app_component(comp, title_obj)
          progress "Title Editor: setting App-based component criteria for Patch '#{version}' of SoftwareTitle '#{title}'",
                   log: :debug

          comp.criteria.add_criterion(
            name: 'Application Title',
            operator: 'is',
            value: title_obj.app_name
          )

          comp.criteria.add_criterion(
            name: 'Application Bundle ID',
            operator: 'is',
            value: title_obj.app_bundle_id
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
          progress "Title Editor: Enabling Patch '#{version} of SoftwareTitle '#{title}'", log: :debug
          ted_patch.enable

          # Once we have an enabled patch, the title should also be enabled,
          # cuz everything else should be OK to go.
          # Do this thru the title object for logging
          title_object.enable_ted_title
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

      end # TitleEditor

    end # Helpers

  end # Server

end # module Xolo
