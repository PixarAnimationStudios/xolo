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
      module TitleTitleEditor

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
          log_info "Title Editor: Creating SoftwareTitle '#{title}'"
          new_ted_title = Windoo::SoftwareTitle.create(
            id: title,
            name: display_name,
            publisher: publisher,
            appName: app_name,
            bundleId: app_bundle_id,
            currentVersion: Xolo::Server::Title::NEW_TITLE_CURRENT_VERSION,
            cnx: ted_cnx
          )

          update_ted_title_requirements new_ted_title

          self.ted_id_number = new_ted_title.softwareTitleId
        end

        # Update title in the title editor
        #
        # TODO: If title switches from versionscript to app info, all patch components must be updated
        #
        #
        # @param new_data [Hash] The new data sent from xadm
        # @return [void]
        ##########################
        def update_title_in_ted(new_data)
          log_info "Title Editor: Updating SoftwareTitle '#{title}'"

          Xolo::Server::Title::ATTRIBUTES.each do |attr, deets|
            ted_attribute = deets[:ted_attribute]
            next unless ted_attribute

            new_val = new_data[attr]
            old_val = send(attr)
            next if new_val == old_val

            # These changes happen in real time on the Title Editor server
            log_debug "Title Editor: Updating title attribute '#{ted_attribute}': #{old_val} -> #{new_val}"
            ted_title.send "#{ted_attribute}=", new_val
          end

          update_ted_title_requirements ted_title, new_data

          self.ted_id_number = ted_title.softwareTitleId
        end

        # Add or update the requirements in the TItle Editor title.
        # Requirements are criteria indicating that this title (any version)
        # is installed on a client machine.
        #
        # If the Xolo Title has app_name and app_bundle_id defined,
        # they are used as the criteria.
        #
        # If the Xolo Title as a version_script defined, it returns
        # either an empty value, or the version installed on the client
        # it is added to the Title Editor title and used both as the
        # requirement criterion (not empty) and as a Patch Component
        # criterion for versions (the value contains the version)
        # TODO: If title switches from versionscript to app info, all patch components must be updated
        #
        #
        # @param ted_title [Windoo::SoftwareTitle] the TEd title we are changing
        #
        # @return [void]
        ######################
        def update_ted_title_requirements(ted_title, new_data = nil)
          log_debug "Title Editor: Setting Requirements for title '#{title}'"

          # delete the current requirements
          ted_title.requirements.delete_all_criteria

          req_app_name = new_data ? new_data[:app_name] : app_name
          req_app_bundle_id = new_data ? new_data[:app_bundle_id] : app_bundle_id
          req_ea_script = new_data ? new_data[:version_script] : version_script

          if req_app_name && req_app_bundle_id
            update_ted_title_app_requirements(
              ted_title,
              req_app_name: req_app_name,
              req_app_bundle_id: req_app_bundle_id
            )

          elsif req_ea_script
            update_ted_title_ea_requirements ted_title, req_ea_script: req_ea_script

          else
            msg = 'No version_script, nor app_name & app_bundle_id - Cannot create Title Editor Title Requirements'
            log_error msg
            raise Xolo::MissingDataError, msg
          end
        end

        # Update the Title Editor Title Requirements with app name and bundle id.
        # these changes happen immediately on the server
        #
        # @param ted_title [Windoo::SoftwareTitle] the TEd title we are changing
        #
        # @return [void]
        ####################
        def update_ted_title_app_requirements(ted_title, req_app_name:, req_app_bundle_id:)
          log_debug "Title Editor: Setting App-based Requirement Criteria for title '#{title}'"

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

          return unless ted_title.extensionAttribute

          log_debug "Title Editor: Deleting unused Extension Attribute for title '#{title}'"
          ted_title.delete_extensionAttribute
        end

        # Update the Title Editor Title EA  and requireents
        # with the current version_script
        #
        # these changes happen immediately on the server
        #
        # @param ted_title [Windoo::SoftwareTitle] the TEd title we are changing
        #
        # @param ea_script [String] the code of the script.
        #
        # @return [void]
        ####################
        def update_ted_title_ea_requirements(ted_title, req_ea_script:)
          log_debug "Title Editor: Setting ExtensionAttribute version_script and Requirement Criteria for title '#{title}'"

          # delete and recreate the EA
          ted_title.delete_extensionAttribute

          ted_title.add_extensionAttribute(
            key: ted_ea_key,
            displayName: ted_ea_key,
            script: req_ea_script
          )

          # add a requirement criterion using the EA
          # Any value in the EA means the title is installed
          # (the value will be the version that is installd)
          ted_title.requirements.add_criterion(
            type: 'extensionAttribute',
            name: ted_ea_key,
            operator: 'matches regex',
            value: '.+'
          )
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
          return if ted_title.enabled?

          log_debug "Title Editor: Enabling SoftwareTitle '#{title}'"
          ted_title.enable
        end

        # Delete from the title editor
        # @return [Integer] title editor id number
        ###########################
        def delete_title_from_ted
          log_info "Title Editor: Deleting SoftwareTitle '#{title}'"

          ted_title.delete
        rescue Windoo::NoSuchItemError
          ted_id_number
        end

      end # TitleEditorTitle

    end # Mixins

  end # Server

end # module Xolo
