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

module Xolo

  
  module RubyExtensions

    module Array

      module Predicates

        def self.included(includer)
          Xolo.load_msg "--> #{includer} is including #{self}"
        end
        
        # A case-insensitive version of #include? 
        #
        # Array elements that don't respond to casecmp? are ignored.
        #
        # (Strings and Symbols do respond)
        #
        # @param somestring [String] the String to search for
        #
        # @return [Boolean] Does the Array contain the String, ignoring case?
        #
        def x_ci_include?(somestring)
          any? { |s| s.respond_to?(:casecmp?) && s.casecmp?(somestring) }
        end

      end # module

    end # module

  end # module

end
