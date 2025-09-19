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

    module BaseClasses

      # The base class for dealing with Titles and Versions/Patches in the
      # Xolo Server, Admin, and Client modules.
      #
      # The base class for "xolo objects stored on the xolo server", i.e.
      # Titles and Versions/Patches - whether they are being used on the server,
      # in xadm, or in the client.
      #
      # This class holds stuff common to all no matter where or how they are used.
      #
      # See also {Xolo::Core::BaseClasses::Title} and {Xolo::Core::BaseClasses::Version}
      #############################
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

        # Convert to a Hash for sending between xadm and the Xolo Server,
        # or installing on clients.
        #
        # Only the values defined in ATTRIBUTES are sent, because all other
        # other attributes are meant only for the local context, i.e.
        # on the server, via xadm, or via 'xolo'.
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
        # gets stored in files that humans will look at
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
