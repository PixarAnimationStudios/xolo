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

      # The base class for dealing with the 'Components' of a Patch
      # in the TitleEditor and the Admin modules.
      #
      # There can only be one component, even though its stored in an
      # Array. The component is used to define which computers have
      # this specific patch installed.
      #
      class Component < Xolo::Core::BaseClasses::JSONObject

        # Attributes
        ######################

        JSON_ATTRIBUTES = {

          # @!attribute componentId
          # @return [Integer] The id number of this component
          componentId: {
            class: :Integer,
            identifier: :primary
          },

          # @!attribute patchId
          # @return [Integer] The id number of the patch which uses this component
          patchId: {
            class: :Integer
          },

          # @return [String] The name of the Software Title for this patch
          # @return [String] The id number of the patch which uses this component
          name: {
            class: :String
          },

          # @!attribute version
          # @return [String] The version installed by this patch
          version: {
            class: :String
          }

          # DEFINE THIS IN THE SUBCLASSES OF Xolo::Core::BaseClasses::ComponentCriterion

          # _!attribute criteria
          # _return [Array<Xolo::Core::BaseClasses::ComponentCriterion>] The criteria used by
          # this component.
          # criteria: {
          #   class: Xolo::Core::BaseClasses::ComponentCriterion,
          #   multi: true
          # }

        }.freeze

      end # class Component

    end # module BaseClasses

  end # module Core

end # module Xolo
