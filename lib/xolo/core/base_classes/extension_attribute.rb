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

      # The base class for dealing with Software Title Requirements in the
      # TitleEditor and the Admin modules.
      #
      # A requirement is one criterion, a group of which define which computers
      # have the title installed, regardless of version.
      class ExtensionAttribute < Xolo::Core::BaseClasses::JSONObject

        # Attributes
        ######################

        JSON_ATTRIBUTES = {

          # @!attribute extensionAttributeId
          # @return [Integer] The id number of this extension attribute in the Title Editor
          extensionAttributeId: {
            class: :Integer,
            identifier: :primary
          },

          # @!attribute softwareTitleId
          # @return [Integer] The id number of the title which uses this extension attribute
          softwareTitleId: {
            class: :Integer
          },

          # @!attribute key
          # @return [String] The name of the extension attribute as it appears in Jamf Pro
          #    NOTE: must be unique in Jamf Pro.
          key: {
            class: :String
          },

          # @!attribute value
          # @return [String] The Base64 encoded script code for this extension attribute
          value: {
            class: :String
          },

          # @!attribute displayName
          # @return [String] The name of the extension attribute as it appears in Title Editor
          displayName: {
            class: :String
          }

        }.freeze

        # Public Instance Methods
        ######################

        # @return [String] The script code for this extension attribute
        def script
          require 'base64'
          Base64.decode64 value
        end

      end # class ExtensionAttribute

    end # module BaseClasses

  end # module Core

end # module Xolo
