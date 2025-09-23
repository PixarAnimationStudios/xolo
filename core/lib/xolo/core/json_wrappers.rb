# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#
#

# frozen_string_literal: true

# main module
module Xolo

  module Core

    # constants and methods for consistent JSON processing on the server
    module JSONWrappers

      # when this module is extended
      def self.extended(extender)
        Xolo.verbose_extend extender, self
      end

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # A wrapper for JSON.parse that always uses :symbolize_names
      # def self.parse_json(str)
      #   JSON.parse str, symbolize_names: true
      # end

      # A wrapper for JSON.parse that always uses :symbolize_names
      # and ensures UTF-8 encoding
      def parse_json(str)
        JSON.parse str.force_encoding('UTF-8'), symbolize_names: true
      end

    end # JSON

  end # Core

end # module Xolo
