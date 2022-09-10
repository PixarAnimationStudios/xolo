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

    # The base class for objects that are instantiated from 
    # a JSON Hash
    class JSONObject

      # Constants
      ######################

      # When using prettyprint, don't spit out these instance variables.
      PP_OMITTED_INST_VARS = %i[@init_data].freeze

      # Attributes
      ######################
      
      # @return [Hash] The raw JSON data this object was instantiated with
      attr_reader :init_data

      # Constructor
      ######################
      def initialize(json_data)
        @init_data = json_data
        @init_data.each do |key, val|
          next unless respond_to? key

          instance_variable_set "@#{key}", val
        end
      end

      # Only selected items are displayed with prettyprint
      # otherwise its too much data in irb.
      #
      # @return [Array] the desired instance_variables
      #
      def pretty_print_instance_variables
        @pp_inst_vars ||= instance_variables - PP_OMITTED_INST_VARS
      end

    end # class RequirementBase

  end # module Code

end # module
