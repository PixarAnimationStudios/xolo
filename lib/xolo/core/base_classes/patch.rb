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

      # The base class for dealing with the Patches of a Software Title
      # 
      class Patch < Xolo::Core::BaseClasses::JSONObject

        # Attributes
        ######################
        
        JSON_ATTRIBUTES = {

          # @!attribute patchId
          # @return [Integer] The id number of this patch
          patchId: {
            class: :Integer
          },
  
          # @!attribute softwareTitleId
          # @return [Integer] The id number of the title which uses this patch 
          softwareTitleId: {
            class: :Integer
          },
  
          # @!attribute absoluteOrderId
          # @return [Integer] The zero-based position of this patch among
          #   all those used by the title. Should be identical to the Array index
          #   of this patch in the #patches attribute of the SoftwareTitle
          #   instance that uses this patch
          absoluteOrderId: {
            class: :Integer
          },
  
          # @!attribute enabled
          # @return [Boolean] Is this patch enabled?
          enabled: {
            class: :Boolean
          },
  
          # @!attribute version
          # @return [String] The version on the title installed by this patch
          version: {
            class: :String
          },
  
          # @!attribute releaseDate
          # @return [Time] When this patch was released
          releaseDate: {
            class: :Time
          },
  
          # @!attribute standalone
          # @return [Boolean] Can this patch be installed as an initial installation?
          #   If not, it must be applied to an already-installed version of this title.
          standalone: {
            class: :Boolean
          },
  
          # @return [String] The lowest version of the OS that can run this patch
          #   NOTE: This is for reporting only. You'll still need to specify it in the 
          #   capabilities for this patch.
          minimumOperatingSystem: {
            class: :String
          },
  
          # @!attribute reboot
          # @return [Boolean] Does the patch require a reboot after installation?
          reboot: {
            class: :Boolean
          }
          
          # DEFINE THESE  IN THE SUBCLASSES OF Xolo::Core::BaseClasses::Patch

          # _!attribute killApps
          # _return [Array<Xolo::Core::BaseClasses::KillApp>] The apps that must be quit before 
          #   installing this patch
          # killApps: {
          #   class: Xolo::Core::BaseClasses::KillApp,
          #   multi: true
          # }

          # _!attribute components
          # _return [Array<Xolo::Core::BaseClasses::Component>] The components of this patch.
          #   NOTE: there can be only one!
          # components: {
          #   class: Xolo::Core::BaseClasses::Component,
          #   multi: true
          # }
          
          # _!attribute capabilities
          # _return [Array<Xolo::Core::BaseClasses::Capability>] The criteria which identify
          #   computers capable of running, and thus installing, this patch.
          # capabilities: {
          #   class: Xolo::Core::BaseClasses::Capability,
          #   multi: true
          # }
          
          # _!attribute dependencies
          # _return [Array<Xolo::Core::BaseClasses::Dependency>] NOT CURRENTLY IMPLEMENTED
          #   The JSON data from the Title Editor is always an empty array, and
          #   the Title Editor UI has no indication this exists.
          # dependencies: {
          #   class: Xolo::Core::BaseClasses::Dependency,
          #   multi: true
          # }

        }.freeze

      end # class Patch

    end # module BaseClasses

  end # module Core

end # module Xolo
