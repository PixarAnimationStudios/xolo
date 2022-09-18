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

      # The base class for dealing with criteria in Software Titles.
      # 
      # Criteria are individual comparisons or 'filter rules' used singly 
      # or in ordered groups to identify matching computers, much as they
      # are used for Jamf Smart Groups or Advanced Searches.
      # 
      # For example, a single criterion might specify all computers where
      # the app 'FooBar.app' is installed. Another might specify that
      # FooBar.app is version 12.3.6, or that the OS is Big Sur or higher.
      #
      # In SoftwareTitles, criteria are used in three places:
      #
      # - As the 'requirements' of a Software Title.
      #   Each requrement is one criterion, and the Array of them
      #   define which computers have any version of the title
      #   installed.
      #
      # - As the criteria of the sole 'component' of a Patch.
      #   A Patch's 'components' is an Array of one item (for historical
      #   reasons apparently).  That component contains an Array of
      #   criteria that define which computers have _that specific_
      #   version of the Patch's Title installed.
      #
      # - As the 'capabilities' of a Patch.
      #   Each capability is one criterion, and the Array of them
      #   define which computers are capable of running, and thus
      #   allowed to install, this Patch.
      #
      class Criterion < Xolo::Core::BaseClasses::JSONObject

        # Constants
        #####################

        # The authoritative list of available types can be read from the API
        # at GET 'valuelists/criteria/types'

        TYPE_RECON = 'recon'
        TYPE_EA = 'extensionAttribute'

        TYPES = [TYPE_RECON, TYPE_EA].freeze

        # Attributes
        ######################

        JSON_ATTRIBUTES = {

          # @!attribute absoluteOrderId
          # @return [Integer] The zero-based position of this requirement among
          #   all those used by the title. Should be identical to the Array index
          #   of this requirement in the #requirements attribute of the SoftwareTitle
          #   instance that uses this requirement
          absoluteOrderId: {
            class: :Integer
          },

          # @!attribute and_or
          # @return [Symbol] Either :and or :or. This indicates how this criterion is
          #   joined to the next in a chain of boolean logic.
          #   NOTE: In the Title Editor JSON data, this key for this value is the 
          #   word "and" and its value is a boolean: if false, the joiner is "or". 
          #   However, because "and" is a reserved word in ruby, we convert that 
          #   value into this one during initialization, and back when sending
          #   data to the Title Editor.
          and_or: {
            class: :Symbol
          },

          # @!attribute name
          # @return [String] The name of the criteria to search in this requirement.
          #    See the API resource GET 'valuelists/criteria/names'
          name: {
            class: :String
          },

          # @!attribute operator
          # @return [String] The criteria operator to apply to the criteria name
          #    See the API resource POST 'valuelists/criteria/names',  {name: 'Criteria Name'}
          operator: {
            class: :String
          },

          # @!attribute value
          # @return [String] The the value to apply with the operator to the named criteria
          value: {
            class: :String
          },

          # @!attribute type
          # @return [String] What type of criteria is the named one? 
          #   Must be one of the values in TYPES
          type: {
            class: :String
          }
        }.freeze
    

        # Constructor
        ######################
        def initialize(json_data)
          super
          @and_or = @init_data[:and] == false ? :or : :and
        end

      end # class Criterion

    end # module BaseClasses

  end # module Core

end # module Xolo
