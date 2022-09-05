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

module Xolo

  module RubyExtensions

    module String

      module Conversions

        def self.included(includer)
          Xolo.load_msg "--> #{includer} is including #{self}"
        end

        TRUE_STRINGS_RE = /^(true|y(es)?)$/i.freeze
        FALSE_STRINGS_RE = /^(false|n(o)?)$/i.freeze

        # Convert the strings 
        #   "true", "yes", and "y" to boolean true
        #   "false", "no", and "n" to boolean false
        #
        # - case insensitive
        # - strings are striped of leading & trailing whitespace
        #   before comparison
        #
        # Return nil if any other string.
        #
        # @return [Boolean,nil] the boolean value
        #
        def x_to_bool
          case strip
          when TRUE_STRINGS_RE then true
          when FALSE_STRINGS_RE then false
          end # case
        end # to bool

        # Convert a string to a Time object
        #
        # @return [Time] the time represented by the string, or nil
        #
        def x_to_time
          Time.parse self
        rescue
          nil
        end

        # Convert a String to a Pathname object
        #
        # @return [Pathname]
        #
        def x_to_pathname
          Pathname.new self
        end

      end # module

    end # module

  end # module

end # module
