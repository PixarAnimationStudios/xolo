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
# 
# 

require 'singleton'

module Xolo

  module Core

    # A class for working with pre-defined settings & preferences for Xolo
    # 
    # This is a singleton class, only one instance can exist at a time.
    # 
    # When the module loads, that instance is created, and is used to provide default 
    # values throughout Xolo. It can be accessed via Xolo.config in applications.
    #
    # @note Many values in Xolo will also have a hard-coded default, if not defined
    # in the configuration.
    # 
    # When the Xolo::Configuration instance is created, the {GLOBAL_CONF} file (/etc/xolo.conf) 
    # is examined if it exists, and the items in it are loaded into the attributes.
    # 
    # Then the user-specific {USER_CONF} file (~/.xolo.conf) is examined if it exists, and 
    # any attributes defined there will override those values from the {GLOBAL_CONF}.
    # 
    # The file format is one attribute per line, thus:
    #   attr_name: value
    # 
    # Lines that don't start with a known attribute name followed by a colon are ignored. 
    # If an attribute is defined more than once, the last one wins.
    # 
    # See {CONF_KEYS} for the available attributes, and how they are converted to the appropriate
    # Ruby class when loaded.
    # 
    # At any point, the attributes can read or changed using standard Ruby getter/setter methods
    # matching the name of the attribute,
    # e.g.
    #
    #   # read the current title_editor_server_name configuration value
    #   Xolo.config.title_editor_server_name  # => 'foobar.appcatalog.jamfcloud.com'
    #
    #   # sets the title_editor_server_name to a new value
    #   Xolo.config.title_editor_server_name = 'baz.appcatalog.jamfcloud.com' 
    # 
    # 
    # The current settings may be saved to the GLOBAL_CONF file, the USER_CONF file, or an arbitrary
    # file using {#save}.  The argument to {#save} should be either :user, :global, or a String or
    # Pathname file path.
    # NOTE: This overwrites any existing file with the current values of the Configuration object.
    # 
    # To re-load the configuration use {#reload}. This clears the current settings, and re-reads 
    # both the global and user files. If a pathname is provided, e.g.
    #   Xolo.config.reload '/path/to/other/file'
    # the current settings are cleared and reloaded from that other file.
    # 
    # To view the current settings, use {#print}.
    # 
    class Configuration

      include Singleton

      # Class Constants
      #####################################

      # The filename for storing the config, globally or user-level.
      # The first matching file is used - the array provides
      # backward compatibility with earlier versions.
      # Saving will always happen to the first filename
      CONF_FILENAME = 'xolo.conf'

      # The Pathname to the machine-wide preferences plist
      GLOBAL_CONF = Pathname.new "/etc/#{CONF_FILENAME}" 

      # The Pathname to the user-specific preferences plist
      USER_CONF = Pathname.new("~/.#{CONF_FILENAME}").expand_path

      # The attribute keys we maintain, and the type they should be stored as
      CONF_KEYS = {
        title_editor_server_name: :to_s,
        title_editor_server_port: :to_i,
        title_editor_ssl_version: :to_s,
        title_editor_verify_cert: :to_bool,
        title_editor_username: :to_s,
        title_editor_open_timeout: :to_i,
        title_editor_timeout: :to_i
      }

      # Attributes
      #####################################

      # automatically create accessors for all the CONF_KEYS
      CONF_KEYS.keys.each { |k| attr_accessor k }

      
      # Constructor
      #####################################

    
      # Initialize!
      # 
      def initialize
        read GLOBAL_CONF
        read USER_CONF
      end

      # Public Instance Methods
      #####################################

      # Clear all values
      # 
      # @return [void]
      # 
      def clear_all
        CONF_KEYS.keys.each { |k| send "#{k}=", nil }
      end

      # Clear the settings and reload the prefs files, or another file if provided
      # 
      # @param file[String,Pathname] a non-standard prefs file to load
      # 
      # @return [void]
      # 
      def reload(file = nil)
        clear_all
        if file
          read file
          return true
        end
        read GLOBAL_CONF
        read USER_CONF
        true
      end

      # Save the prefs into a file
      # 
      # @param file[Symbol,String,Pathname] either :user, :global, or an arbitrary file to save.
      # 
      # @return [void]
      # 
      def save(file)
        path = 
          case file
          when :global then GLOBAL_CONF
          when :user then USER_CONF
          else Pathname.new(file)
          end

        # file already exists? read it in and update the values.
        if path.readable?
          data = path.read

          # go thru the known attributes/keys
          CONF_KEYS.keys.sort.each do |k|
            curr_val = send(k)

            # if the key exists, update it.
            if data =~ /^\s*#{k}:/
              data.sub!(/^\s*#{k}:.*$/, "#{k}: #{curr_val}")

            # if not, add it to the end unless it's nil
            else
              data += "\n#{k}: #{curr_val}" unless curr_val.nil?
            end # if data =~ /^#{k}:/
          end # each do |k|

        else # not readable, make a new file
          data = ''
          CONF_KEYS.keys.sort.each do |k|
            data << "#{k}: #{send k}\n" unless send(k).nil?
          end
        end # if path readable

        # make sure we end with a newline, the save it.
        data << "\n" unless data.end_with?("\n")
        path.x_save data
      end # read file

      # Print out the current settings to stdout
      # 
      # @return [void]
      # 
      def print
        CONF_KEYS.keys.sort.each { |k| puts "#{k}: #{send k}" }
      end

      # Private Instance Methods
      #####################################
      private

      # Read in any prefs file
      # 
      # @param file[String,Pathname] the file to read
      # 
      # @return [void]
      # 
      def read(file)
        file = Pathname.new file
        return unless file.readable?

        file.read.each_line do |line|
          # skip blank lines and those starting with #
          next if line =~ /^\s*(#|$)/

          # parse the line
          next unless line.strip =~ /^\s*(\w+?):\s*(\S.*)$/

          attr = Regexp.last_match(1).to_sym
          next unless CONF_KEYS.key? attr

          setter = "#{attr}=".to_sym
          value = Regexp.last_match(2).strip
          # convert the value to the correct class
          value &&= value.send(CONF_KEYS[attr])

          send(setter, value)
        end # do line
      end # read file

    end # class Configuration

  end # module Core

end # module
