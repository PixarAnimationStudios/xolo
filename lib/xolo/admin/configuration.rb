# Copyright 2023 Pixar
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

# frozen_string_literal: true

# main module
module Xolo

  module Admin

    # Personal prefs for users of 'xadm'
    class Configuration

      include Singleton

      # Save to yaml file in ~/Library/Preferences/com.pixar.xolo.admin.prefs.yaml
      #
      # - hostname of xolo server
      #   - always port 443, for now
      #
      # Note - credentials for Xolo Server area stored in login keychain.
      # code for that is in the Xolo::Admin::Credentials module.

      ### Constants
      ##############################
      ##############################

      CONF_FILENAME = 'com.pixar.xolo.admin.prefs.yaml'

      ### Class methods
      ##############################
      ##############################

      def self.conf_file
        @conf_file ||= Pathname.new("~/Library/Preferences/#{CONF_FILENAME}").expand_path
      end

    end # class Configuration

  end # module Admin

end # module Xolo
