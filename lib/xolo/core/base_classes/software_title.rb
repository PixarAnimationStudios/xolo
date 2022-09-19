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

# frozen_string_literal: true

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
          #   @return [Integer] The id of this title in the Title Editor
          softwareTitleId: {
            class: :Integer,
            # primary means this is the one used to fetch via API calls
            identifier: :primary
          },

          # @!attribute id
          # @return [String] A string, unique any patch source (in this case
          #   the TitleEditor), that identifies this Software Title.
          #   Can be thought of as the unique name on the Title Editor.
          #   Not to be confused with the 'name' attribute, which is more
          #   of a Display Name, and is not unique
          id: {
            class: :String,
            # true means this is a unique value in and can be used to find a valid
            # primary identifier.
            identifier: true,
            # required means this value is required to create or update this
            # object on the server(s)
            required: true
          },

          # @!attribute enabled
          #   @return [Boolean] Is this title enabled, and available to be subscribed to?
          enabled: {
            class: :Boolean
          },

          # @!attribute name
          #   @return [String] The name of this title in the Title Editor. NOT UNIQUE,
          #     and not an identfier. See 'id'.
          name: {
            class: :String,
            required: true
          },

          # @!attribute publisher
          #   @return [String] The publisher of this software
          publisher: {
            class: :String,
            required: true
          },

          # @!attribute lastModified
          #   @return [Time]  When was the title last modified?
          lastModified: {
            class: Time,

            # for classes (like Time) that are not Symbols (like :String)
            # This is the Class method to call on them to convert the
            # raw API data into the ruby value we want. The API data
            # will be passed as the sole param to this method.
            # For most, it will be :new, but for, e.g., Time, it is
            # :parse
            to_ruby: :parse,

            # The method to call on the value when converting to
            # data to be sent to the API.
            # e.g. on Time values, convert to iso8601
            to_api: :iso8601
          },

          # @!attribute currentVersion
          #   @return [String] the version number of the most recent patch
          currentVersion: {
            class: :String,
            required: true
          }

          # DEFINE THESE  IN THE SUBCLASSES OF Xolo::Core::BaseClasses::SoftwareTitle

          # _!attribute extensionAttributes
          #   _return [Xolo::Core::BaseClasses::ExtensionAttribute] The Extension Attributes used by this title
          # extensionAttributes: {
          #   class: Xolo::Core::BaseClasses::ExtensionAttribute,
          #   multi: true
          # }

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
          #   class: Xolo::Core::BaseClasses::Patch,
          #   multi: true
          # }
        }.freeze

        # Constructor
        ######################
        def initialize(json_data)
          super

          @lastModified &&= Time.parse(lastModified)

          # Do something like this in the subclasses to convert the
          # data to the appropriate classes

          # @requirements =
          #   requirements.map { |data| Xolo::Server::TitleEditor::Requirement.new data }
          # @patches =
          #   patches.map { |data| Xolo::Server::TitleEditor::Patch.new data }
          # @extensionAttributes =
          #   extensionAttributes.map { |data| Xolo::Server::TitleEditor::ExtensionAttribute.new data }
        end

      end # class SoftwareTitle

    end # module BaseClasses

  end # module Core

end # module Xolo
