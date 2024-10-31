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

# frozen_string_literal: true

module Xolo

  module Core

    module BaseClasses

      # A class for working with pre-defined settings & preferences for Xolo
      #
      # This is the base class for Xolo::Server::Configuration and Xolo::Admin::Configuration
      #
      # The subclasses must 'include Singleton', making them use the Singleton Pattern, meaning
      # only one instance can exist at a time.
      #
      # This parent class provides methods for loading and saving YAML files with configuration
      # and prefs settings in the Server or Admin context.
      #
      # The YAML files store a Hash of keys and values relevent to the context
      # they are used in.
      #
      # Subclasses must define these constants and related methods:
      #
      # Constant CONF_FILENAME [String]
      #   The filename (not the full path) of the config yaml file to read and write.
      #
      # Instance method #conf_file [Pathname]
      #  The full expanded absolute path to the config yaml file.
      #
      # Constant KEYS [Hash{Symbol: Hash}]
      #   The keys of this Hash are the keys that may be found in the yaml file.
      #   The Hash values here define the value in the YAML file, with these keys:
      #
      #     required: [Boolean] Is this key/value required in the YAML file? The server
      #        will not start if a required key is missing.
      #
      #     type: [Symbol] The data-type of the value, one of the types supported by
      #       Optimist: :boolean, :string, :integer, :float, :io, :date
      #       See https://github.com/ManageIQ/optimist/wiki/Option-Types
      #
      #     default: [Object] If this key doesn't exist in the YAML file, this is the
      #       value used by Xolo.
      #
      #     desc: [String] A full description of what this value is, how it is used,
      #       possible values, etc. This is presented in help and/or walkthru.
      #
      #     load_method: [Symbol] The name of a method in the Configuration Instance
      #       to which the YAML value will be passed to convert it into the real value
      #       to be used.  For example, some YAML values might contain a command to be
      #       executed, a pathname to be read, or a raw value to be used. These
      #       values should be passed to the :data_from_command_file_or_string method
      #       which will return the value to actually be used (the stdout of a command,
      #       the contents of a file, or a raw value)
      #
      #     private: [Boolean] If true, the value is never presented in logs or normal
      #       output. it is replaced with <private>. Use this for sensitive secrets.
      #
      #
      #
      class Configuration

        # Mixins
        #####################################
        #####################################

        # Constants
        #####################################
        #####################################

        PIPE = '|'

        PRIVATE = '<private>'

        # Class Methods
        #####################################
        #####################################

        def self.inherited(child_class)
          Xolo.verbose_inherit child_class, self
        end

        # Attributes
        #####################################
        #####################################

        # @return [Hash{Symbol: Object}] The data as read directly from the YAML file
        attr_reader :raw_data

        # @return

        # Constructor
        #####################################
        #####################################

        # # Initialize!
        def initialize
          keys.each_key { |attr| self.class.attr_accessor attr }
          load_from_file
        end

        # Public Instance Methods
        #####################################
        #####################################

        ###############
        def to_h
          data = {}
          keys.each_key do |key|
            data[key] = send(key)
          end
          data
        end

        ###############
        def to_h_private
          data = {}
          keys.each do |key, deets|
            data[key] =
              if deets[:private]
                PRIVATE
              else
                send(key)
              end
          end
          data
        end

        # Save new data (or raw_data) to the config file. We don't save the
        # actual instance variables, as they may be expanded from
        # commands or file paths, and its the commands or file paths
        # we want to save.
        #
        ###############
        def save_to_file(data: nil)
          data ||= raw_data
          conf_file.parent.mkpath unless conf_file.parent.directory?
          conf_file.pix_save YAML.dump(data)
          conf_file.chmod 0o600
        end

        # Private Instance Methods
        #####################################
        #####################################
        private

        # Simpler access to the KEYS constant in subclasses
        #
        # @return [Hash]
        #
        ###############
        def keys
          self.class::KEYS
        end

        # Load in the values from the config file
        #
        # @return [void]
        #
        ###############
        ###############
        def load_from_file
          conf_file.parent.mkpath unless conf_file.parent.directory?

          unless conf_file.readable?
            @raw_data = {}
            return
          end

          @raw_data = YAML.load conf_file.read
          @raw_data.each do |k, v|
            next unless keys[k]

            v = send(keys[k][:load_method], v) if keys[k][:load_method]
            send "#{k}=", v
          end
        end

        # If the given string starts with a pipe (|) then
        # remove the pipe and execute the remainder, returning
        # its stdout.
        #
        # If the given string is a readble file path, return
        # its contents.
        #
        # Otherwise, the string is the desired data, so just return it.
        #
        # @param str [String] a command, file path, or string
        #
        # @return [String] The std output of the command, file contents, or string
        #
        ###############
        def data_from_command_file_or_string(str)
          return `#{str.delete_prefix(PIPE)}`.chomp if str.start_with? PIPE

          path = Pathname.new(str)
          return path.read.chomp if path.file? && path.readable?

          str
        end

      end # class Configuration

    end # BaseClasses

  end # Core

end # Xolo
