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

# frozen_string_literal: true

module Xolo

  module Server

    module TitleEditor

      class SoftwareTitle < Xolo::BaseClasses::SoftwareTitle

        # Constants
        ######################

        LOCAL_TITLE_EDITOR_SOURCE_NAME = 'Local'
        LOCAL_TITLE_EDITOR_SOURCE_ID = 0
        
        # Attributes
        ######################

        # @return [String] The name of the Patch Source that hosts ultimately
        #   hosts this title definition. If hosted by our TitleEditor 
        #   directly, this is LOCAL_TITLE_EDITOR_SOURCE_NAME
        attr_reader :source

        # @return [Integer] The id of the Patch Source that hosts ultimately
        #   hosts this title definition. If hosted by our TitleEditor 
        #   directly, this is LOCAL_TITLE_EDITOR_SOURCE_ID
        attr_reader :sourceId

        # Construcor
        ######################
        def initialize(json_data)
          super
          @requirements = requirements.map { |data| Xolo::Server::TitleEditor::Requirement.new data }
          @patches = patches.map { |data| Xolo::Server::TitleEditor::Patch.new data }
          @extensionAttributes = extensionAttributes.map { |data| Xolo::Server::TitleEditor::ExtensionAttribute.new data }
        end

      end # class SoftwareTitle

    end # Module TitleEditor

  end # Module Server

end # Module Xolo
