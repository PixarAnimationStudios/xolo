# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

# frozen_string_literal: true

module Xolo

  module Core

    module Loading

      # touch this file to make mixins send text to stderr as things load
      # or get mixed in
      VERBOSE_LOADING_FILE = Pathname.new('/tmp/xolo-verbose-loading')

      # Or, set this ENV var to also make mixins send text to stderr
      VERBOSE_LOADING_ENV = 'XOLO_VERBOSE_LOADING'

      def self.extended(extender)
        Xolo.verbose_extend extender, self
      end

      # Only look at the filesystem once.
      def verbose_loading?
        return @verbose_loading unless @verbose_loading.nil?

        @verbose_loading = VERBOSE_LOADING_FILE.file?
        @verbose_loading ||= ENV.include? VERBOSE_LOADING_ENV
        @verbose_loading
      end

      # Send a message to stderr if verbose loading is enabled
      def load_msg(msg)
        warn msg if verbose_loading?
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
