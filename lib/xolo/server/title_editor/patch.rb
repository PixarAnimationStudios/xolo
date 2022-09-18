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

  module Server

    module TitleEditor

      class Patch < Xolo::Core::BaseClasses::Patch

        # Attributes
        ######################
        
        JSON_ATTRIBUTES = {

          # @!attribute killApps
          # @return [Array<Xolo::Server::TitleEditor::KillApp>] The apps that must be quit before 
          #   installing this patch
          killApps: {
            class: Xolo::Server::TitleEditor::KillApp,
            multi: true
          },

          # @!attribute components
          # @return [Array<Xolo::Server::TitleEditor::Component>] The components of this patch.
          #   NOTE: there can be only one!
          components: {
            class: Xolo::Server::TitleEditor::Component,
            multi: true
          },
          
          # @!attribute capabilities
          # @return [Array<Xolo::Server::TitleEditor::Capability>] The criteria which identify
          #   computers capable of running, and thus installing, this patch.
          capabilities: {
            class: Xolo::Server::TitleEditor::Capability,
            multi: true
          }

        }.freeze

        # Constructor
        ######################

        def initialize(json_data)
          super
          @killApps = killApps.map { |data| Xolo::Server::TitleEditor::KillApp.new data }
          @components = components.map { |data| Xolo::Server::TitleEditor::Component.new data }
          @capabilities = capabilities.map { |data| Xolo::Server::TitleEditor::Capability.new data }
        end

      end # class Patch

    end # module 

  end

end # module
