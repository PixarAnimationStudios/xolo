# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

# frozen_string_literal: true

module Xolo

  module Core

    module Loading

      def self.extended(extender)
        Xolo.verbose_extend extender, self
      end

      # Use the load_msg method defined for Zeitwerk
      def load_msg(msg)
        XoloZeitwerkConfig.load_msg msg
      end

      # Mention that a module is being included into something
      def verbose_include(includer, includee)
        load_msg "--> #{includer} is including #{includee}"
      end

      # Mention that a module is being extended into something
      def verbose_extend(extender, extendee)
        load_msg "--> #{extender} is extending #{extendee}"
      end

      # Mention that a module is being extended into something
      def verbose_inherit(child_class, parent_class)
        load_msg "--> #{child_class} is a Subclass inheriting from #{parent_class}"
      end

    end # module

  end # module

end # module Xolo
