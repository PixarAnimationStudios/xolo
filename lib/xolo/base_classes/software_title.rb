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
    class SoftwareTitle < Xolo::BaseClasses::JSONObject

      # Attributes
      ######################

      # @return [Integer] The id number of this title in the Title Editor
      attr_reader :softwareTitleId
            
      # @return [String] A unique string identifying this title on its
      #   Title Editor server
      attr_reader :id

      # @return [Boolean] Is this title enabled, and available to be subscribed to?
      attr_reader :enabled
      alias enabled? enabled

      # @return [String] The name of this title in the Title Editor
      attr_reader :name
      
      # @return [String] The publisher of this software
      attr_reader :publisher

      # @return [Time] When was the title last modified?
      attr_reader :lastModified

      # @return [String] the version number of the most recent patch
      attr_reader :currentVersion

      # @return [Array<RequirementBase>] The requirements - criteria that 
      #   define which computers have the software installed.
      attr_reader :requirements

      # @return [Integer] How many patches are available for this software
      attr_reader :patches

      # Constructor
      ######################
      def initialize(json_data)
        super
        @lastModified = Time.parse(lastModified)

        # Do this in the subclasses to convert the
        # requirements to the appropriate class
        # @requirements.map! { |data| Xolo::Server::TitleEditor::Requirement.new data }
      end

    end # class SoftwareTitleBase

  end # module Code

end # module
