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

  module BaseClasses

  
    # The base class for dealing with Software Titles in the 
    # TitleEditor and the Admin modules.
    class Requirement < Xolo::BaseClasses::JSONObject

      # The definitive list of available types can be read from the API
      # at GET 'valuelists/criteria/types'

      TYPE_RECON = 'recon'
      TYPE_EA = 'extensionAttribute'

      TYPES = [TYPE_RECON, TYPE_EA].freeze

      # Attributes
      ######################

      # @return [Integer] The id number of this requirement in the Title Editor
      attr_reader :requirementId

      # @return [Integer] The id number of this title which uses this requirement 
      attr_reader :softwareTitleId
            
      # @return [Integer] The zero-based position of this requirement among
      #   all those used by the title. Should be identical to the Array index
      #   of this requirement in the #requirements attribute of the SoftwareTitle
      #   instance that uses this requirement
      attr_reader :absoluteOrderId

      # @return [Boolean] Is this requirement joined to the next with 'and'?
      #   if false, it is joined to the next with 'or'
      attr_reader :and
      alias and? and

      # @return [String] The name of the criteria to search in this requirement.
      #    See the API resource GET 'valuelists/criteria/names'
      attr_reader :name
      
      # @return [String] The criteria operator to apply to the criteria name
      #    See the API resource POST 'valuelists/criteria/names',  {name: 'Criteria Name'}
      attr_reader :operator

      # @return [String] The the value to apply with the operator to the named criteria
      attr_reader :value

      # @return [String] What type of criteria is the named one? 
      #   Must be one of the values in TYPES
      attr_reader :type   

      # Constructor
      ######################
      def initialize(json_data)
        json_data.each do |key, val|
          next unless respond_to? key

          instance_variable_set "@#{key}", val
        end
      end

    end # class RequirementBase

  end # module Code

end # module
