# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.

# frozen_string_literal: true

module Xolo

  module Core

    # Constants useful throughout Xolo
    #####################################
    module Constants

      # Empty strings are used in various places
      BLANK = ''

      # The value to use when unsetting an option
      NONE = 'none'

      OK = 'OK'

      ERROR = 'ERROR'

      # Several things use x
      X = 'x'

      # CLI options and other things use dashes
      DASH = '-'

      # Several things use dots
      DOT = '.'

      # Cancelling is often an option
      CANCEL = 'Cancel'

      # and we check for things ending with .app
      DOTAPP = '.app'

      DOTJSON = '.json'

      # These are handy for testing values without making new arrays, strings, etc every time.
      TRUE_FALSE = [true, false].freeze

      # lots of things get split on commmas
      COMMA_SEP_RE = /\s*,\s*/.freeze

      # lots of things get joined with commas
      COMMA_JOIN = ', '

      # Some things get split on semicolons
      SEMICOLON_SEP_RE = /\s*;\s*/.freeze

      # Once a thing has been uploaded and saved, this
      # is what the server returns as the  attr value
      ITEM_UPLOADED = 'uploaded'

      DOT_PKG = '.pkg'

      DOT_ZIP = '.zip'

      UNKNOWN = 'unknown'

      # Installer packages must have one of these extensions
      OK_PKG_EXTS = [DOT_PKG, DOT_ZIP]

      # The value to use when all computers are the release-targets
      # and for all manual-install policies
      TARGET_ALL = 'all'

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

    end # module constants

  end # module core

end # module Xolo
