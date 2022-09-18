# Copyright 2022 Pixar
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

# main module
module Xolo

  module Core

    module BaseClasses

      # The base class for dealing with Software Titles in the 
      # TitleEditor and the Admin modules.
      class SoftwareTitle < Xolo::Core::BaseClasses::JSONObject

        # Attributes
        ######################

        JSON_ATTRIBUTES = {

          # @!attribute softwareTitleId
          #  @return [Integer] The id number of this title in the Title Editor
          softwareTitleId: {
            class: :Integer, 
            identifier: :primary,
            readonly: true
          },

          # @!attribute id
          #  @return [String] A unique string identifying this title in the
          #    Title Editor
          id: {
            class: :String,
            identifier: true
          },

          # @!attribute enabled
          #   @return [Boolean] Is this title enabled, and available to be subscribed to?
          enabled: {
            class: :Boolean
          },

          # @!attribute name
          #   @return [String] The name of this title in the Title Editor
          name: {
            class: :String
          },

          # @!attribute publisher
          #   @return [String] The publisher of this software
          publisher: {
            class: :String
          },

          # @!attribute lastModified
          #   @return [Time]  When was the title last modified?
          lastModified: {
            class: :Time
          },

          # @!attribute currentVersion
          #   @return [String] the version number of the most recent patch
          currentVersion: {
            class: :String
          },

          # @!attribute extensionAttributes
          #   @return [Xolo::BaseClasses::ExtensionAttribute] The Extension Attributes used by this title
          extensionAttributes: {
            class: :ExtensionAttribute,
            multi: true
          }

          # DEFINE THESE  IN THE SUBCLASSES OF Xolo::Core::BaseClasses::SoftwareTitle

          # _!attribute requirements
          #   _return [Array<Xolo::Core::BaseClasses::Requirement>] The requirements - criteria that 
          #     define which computers have the software installed.
          # requirements: {
          #   class: Xolo::Core::BaseClasses::Requirement,
          #   multi: true
          # },

          # _!attribute patches
          #   _return [Array<Xolo::Core::BaseClasses::Patch>] The patches available for this title
          # patches: {
          #   class: Xolo::Core::BaseClasses::Requirement,
          #   multi: true
          # }
        }.freeze

        
        # Constructor
        ######################
        def initialize(json_data)
          super
          @lastModified &&= Time.parse(lastModified)

          # Do this in the subclasses to convert the
          # requirements to the appropriate class
          # @requirements.map { |data| Xolo::Server::TitleEditor::Requirement.new data }
        end

      end # class SoftwareTitle

    end # module BaseClasses

  end # module Core

end # module Xolo
