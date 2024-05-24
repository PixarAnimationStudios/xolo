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
      module TitleJamfPro

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
        # These are available directly in sinatra routes and views
        #
        ##############################
        ##############################

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

        # create/activate the patch title in Jamf Pro, if not already done
        #
        # This 'subscribes' Jamf to the title in the title editor
        # It must be enabled in the Title Editor first
        # or it won't show up as available.
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
              cnx: jamf_cnx
            )

          title_in_jamf_patch.save

          msg = "Jamf: Activated Patch Title '#{display_name}' (#{title}) from the Title Editor Patch Source '#{Xolo::Server.config.ted_patch_source}'"
          progress msg, log: :info

          accept_xolo_ea_in_jamf
        end

        # TODO: make this a config setting, users should be able to require manual acceptance.
        # Also - handle it not being accepted yet.
        #
        # TODO: when this is implemented in ruby-jss, use the direct implementation
        #
        ############################
        def accept_xolo_ea_in_jamf
          title_id = Jamf::PatchTitle.map_all(:id, to: :name_id, cnx: jamf_cnx).invert[title]
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

          # requires CRUD provs for computer ext attrs
          jamf_cnx.jp_patch "v2/patch-software-title-configurations/#{title_id}", patchdata
          progress "Jamf: Accepted use of ExtensionAttribute version script '#{ted_ea_key}'", log: :debug
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

        # @return [Jamf::PatchTitle] The Jamf Patch Title for this Xolo Title
        ########################
        def jamf_patch_title
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

        # Delete an entire title from Jamf Pro
        ########################
        def delete_title_from_jamf
          # now delete ('unsubscribe') in Jamf Patch Mgmt
          delete_patch_title_from_jamf
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

      end # TitleJamfPro

    end # Mixins

  end # Server

end # Xolo
