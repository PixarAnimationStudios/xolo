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

      # These are handy for testing values without making new arrays, strings, etc every time.
      TRUE_FALSE = [true, false].freeze

      # lots of things get split on commmas
      COMMA_SEP_RE = /\s*,\s*/.freeze

      # lots of things get joined with commas
      COMMA_JOIN = ', '

      # Once a thing has been uploaded and saved, this
      # is what the server returns as the  attr value
      ITEM_UPLOADED = 'uploaded'

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

    end # module constants

  end # module core

end # module Xolo
