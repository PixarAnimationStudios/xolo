# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
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
      def ted_titles
        server_cnx.get(TITLES_ROUTE).body
      end

    end # module

  end # module Admin

end # module Xolo
