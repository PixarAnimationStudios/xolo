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

      # The base class for dealing with Kill Apps
      # TitleEditor and the Admin modules.
      # 
      # A kill app is used by a patch to indicate which running applications
      # must be quit before the patch can be installed.
      class KillApp < Xolo::Core::BaseClasses::JSONObject

        # Attributes
        ######################

        JSON_ATTRIBUTES = {

          # @!attribute killAppId
          # @return [Integer] The id number of this kill app
          killAppId: {
            class: :Integer
          },

          # @!attribute patchId
          # @return [Integer] The id number of the patch which uses this
          #   kill app        
          patchId: {
            class: :Integer
          },

          # @!attribute bundleId
          # @return [String] The bundle id of the app that must be quit
          #   e.g. com.apple.Safari        
          bundleId: {
            class: :String
          },

          # @!attribute appName
          # @return [String] The name of the app that must be quit
          appName: {
            class: :String
          }

        }

      end # class KillApp

    end # module BaseClasses

  end # module Core

end # module Xolo
