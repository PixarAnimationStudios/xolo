# Copyright 2024 Pixar
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

    # Methods that process the xadm commands and their options
    #
    module TitleEditor

      # Constants
      ##########################
      ##########################

      TITLE_EDITOR_ROUTE_BASE = '/title-editor'

      # Xolo server route to the list of titles
      TITLES_ROUTE = "#{TITLE_EDITOR_ROUTE_BASE}/titles"

      # Module Methods
      ##########################
      ##########################

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # when this module is extended
      def self.extended(extender)
        Xolo.verbose_extend extender, self
      end

      # Instance Methods
      ##########################
      ##########################

      # Perhaps not needed for anything, but used for initial connection testing
      # @return [Array<String>] the titles of all Title objects in the Title Editor
      #######################
      def title_editor_titles
        server_cnx.get(TITLES_ROUTE).body
      end

    end # module

  end # module Admin

end # module Xolo
