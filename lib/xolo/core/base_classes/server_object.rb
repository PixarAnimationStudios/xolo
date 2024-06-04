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

  module Core

    module BaseClasses

      # The base class for dealing with Titles and Versions/Patches in the
      # Xolo Server and Admin modules.
      #
      class ServerObject

        # Mixins
        #############################
        #############################

        extend Xolo::Core::JSONWrappers

        include Xolo::Core::JSONWrappers

        # Constants
        #############################
        #############################

        # Attributes
        #############################
        #############################

        # Constructor
        ######################
        ######################
        def initialize(data_hash)
          # log_debug "Instantiating a #{self.class}..."

          self.class::ATTRIBUTES.each do |attr, deets|
            val = data_hash[attr]

            # log_debug "Initializing, setting ATTR '#{attr}' => '#{val}' (#{val.class})"

            # anything not nil, esp empty arrays, needs to be set
            next if val.nil?

            # convert timestamps to Time objects if needed,
            # All the other values shouldn't need converting
            # when taking in JSON or xadm opts.
            val = Time.parse(val.to_s) if deets[:type] == :time && !val.is_a?(Time)

            # call the setter
            send "#{attr}=", val
          end
        end

        # Instance Methods
        ######################
        ######################

        # Convert to a Hash for sending between xadm and the Xolo Server
        #
        # @return [String] The attributes of this title as JSON
        #####################
        def to_h
          hash = {}
          self.class::ATTRIBUTES.each do |attr, deets|
            hash[attr] = send attr

            # ensure multi values are arrays, even if they are empty
            hash[attr] = [hash[attr]].compact if deets[:multi] && !hash[attr].is_a?(Array)
          end
          hash
        end

        # Convert to a JSON object for sending between xadm and the Xolo Server
        # or storage on the server.
        #
        # Always make it 'pretty', i.e.  human readable, since it often
        # gets stored in files
        #
        # @return [String] The attributes of this title as JSON
        #####################
        def to_json(*_args)
          JSON.pretty_generate to_h
        end

      end # class Title

    end # module BaseClasses

  end # module Core

end # module Xolo
