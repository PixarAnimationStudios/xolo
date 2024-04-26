# Copyright 2023 Pixar
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

    # This should be extended into the Xolo module
    #
    # The methods load_yaml and save_yaml are wrappers around
    # YAML.safe_load and YAML.[safe_]dump.
    #
    # The extend the permitted 'safe' classes to include Date, Time,
    # Symbol, an Pathname, which are all fine for Xolo.
    #
    # Also - YAML.safe_dump doesn't exist before Psych v 4.0.1, so
    # our save_yaml method will check the data for safety before
    # calling YAML.dump
    module YAMLWrappers

      # Constants
      #########################

      # The classes allowed by Psych already
      SAFE_CLASSES = [
        TrueClass,
        FalseClass,
        NilClass,
        Integer,
        Float,
        String,
        Array,
        Hash
      ].freeze

      # In addition to the default classes allowed by YAML.safe_load
      # these are also allowed.
      #
      # see https://www.rubydoc.info/stdlib/psych/Psych%2Esafe_load
      #
      # IMPORTANT: Xolo should not dump or attempt to load any YAML
      # with classes other than these and the defaults.
      PERMITTED_CLASSES = [
        Date,
        Time,
        Symbol,
        Pathname,
        Xolo::Server::Title,
        Xolo::Server::Version
      ].freeze

      OK_CLASSES = SAFE_CLASSES + PERMITTED_CLASSES

      # Class Methods
      ##################################
      ##################################

      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # Use YAML.safe_load with expanded permitted classes, symbolized names, and allowing aliases.
      #
      # The allowing of YAML aliases opens the risk of 'YAML Bomb' DoS with untrusted source
      # data. However, because the ruby YAML/Psych module doesn't have a 'safe_dump' method, it is
      # likely that data we save will have aliases, so we must allow loading them. Therefore:
      # DO NOT USE THIS METHOD TO LOAD UNTRUSTED DATA.
      #
      # Xolo uses only JSON for data exchange over a network (or XML for sending to the Jamf
      # Classic API).
      #
      # YAML is only used by the server, xadm, and the xolo client for dealing with local
      # files that it generates.
      #
      # If the param is a Pathname to an existing file, that file is read to get
      # the String of YAML to be loaded.
      #
      # If the param is a String that is a path to an existing file, that file is
      # read to get the String of YAML to be loaded.
      #
      # Otherwise the param is treated as the String of YAML to be loaded.
      #
      # @param src [String, Pathname] A path as a String or Pathname, or a String of YAML
      #
      # @return [Object] the YAML parsed into a ruby data structure.
      ##############################
      def self.load_yaml(src)
        path = Pathname.new(src)
        filename = nil
        if path.file?
          src = path.read
          filename = path.to_s
        end

        YAML.safe_load(
          src,
          permitted_classes: PERMITTED_CLASSES,
          aliases: true,
          filename: filename,
          symbolize_names: true
        )
      end

      # Save something as YAML to a file.
      # WARNING: This will overwrite any existing file.
      #
      # NOTE: Only the classes allowed by YAML.safe_load, plus those defined
      # in PERMITTED_CLASSES are allowed in the data.
      #
      # @param data [Object] The item to be saved
      #
      # @param path [String, Pathname] The file to which the YAML should be written
      #
      # @return [void]
      #############################
      def self.dump_yaml(data)
        dest = Pathname.new(path)

        if YAML.respond_to? :safe_dump
          YAML.safe_dump(data, permitted_classes: PERMITTED_CLASSES)
          return
        end

        examine_object_for_safe_dump data

        YAML.dump(data)
      end

      # Instance Methods
      ##################################
      ##################################

      # wrapper for module method
      #############################
      def load_yaml(src)
        Xolo::Core::YAMLWrappers.load_yaml src
      end

      # wrapper for module method
      #############################
      def dump_yaml(data)
        Xolo::Core::YAMLWrappers.dump_yaml data
      end

      #############################
      private

      # recursively check every object before using
      # YAML.dump.
      def examine_object_for_safe_dump(obj)
        case obj
        when Array
          obj.each { |o| examine_object_for_safe_dump(o) }

        when Hash
          obj.keys.each { |o| examine_object_for_safe_dump(o) }
          obj.values.each { |o| examine_object_for_safe_dump(o) }

        else
          return if OK_CLASSES.include? obj.class

          raise Xolo::DisallowedYAMLDumpClass, "Tried to dump unspecified class: #{obj.class}"
        end
      end

    end # Utility

  end # Core

end # Xolo
