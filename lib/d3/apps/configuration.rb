# Copyright 2018 Pixar
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


#
module D3


  #####################################
  # Module Variables
  #####################################

  #####################################
  # Module Methods
  #####################################

  #####################################
  # Classes
  #####################################

  # A class for working with settings & preferences for the D3 module
  #
  # This is a singleton class, only one instance can exist at a time.
  #
  # When the D3 module loads, the Configuration instance is created and stored
  # in the constant {D3::CONFIG}.
  #
  # Known attributes are listed and defined in the d3.conf.default file
  # in the rubygem folder's data folder
  # (e.g. /Library/Ruby/Gems/2.0.0/gems/depot3-3.0.0/data/d3.conf.default)
  #
  # The current settings may be saved using {Configuration#save}.
  # With no parameter, {#save} writes to the {Configuration::CONF_FILE}
  # otherwise provide a String or Pathname file path.
  # NOTE: This overwrites any existing file.
  #
  # To re-load the settings use {Configuration#reload}. This clears the
  # current settings, and re-reads both the {CONF_FILE}.
  # If a pathname is provided, e.g.
  #   D3::CONFIG.reload '/path/to/other/file'
  # the current settings are cleared and reloaded from that other file.
  #
  # To view the current settings, use {Configuration#print}.
  #
  #
  class Configuration

    include Singleton

    ############### Class Constants #################

    # The filename for storing the prefs, globally
    CONF_FILE = Pathname.new "/etc/d3.conf"


    # The attribute keys we maintain, and the String#method to convert them
    # to the correct ruby class
    # See the d3.conf.default file in the rubygem's data folder
    # for detailed descriptions of these keys.
    # (e.g. /Library/Ruby/Gems/2.0.0/gems/depot3-3.0.0/data/d3.conf.default)
    #
    CONF_KEYS = {

      :jss_default_pkg_category => :to_s,
      :jss_default_script_category => :to_s,

      :log_file => :to_s,
      :log_level => :to_sym,
      :log_timestamp_format => :to_s,

      :client_expiration_allowed => :jss_to_bool,
      :client_expiration_policy => :to_s,
      :client_jss_ro_user => :to_s,
      :client_jss_ropw_path => :to_s,
      :client_db_ro_user => :to_s,
      :client_db_ropw_path => :to_s,
      :client_distpoint_ropw_path => :to_s,
      :client_http_ropw_path => :to_s,
      :client_try_cloud_distpoint => :jss_to_bool,
      :client_prohibited_admin_names =>  [:split,/\s*,\s*/],

      :puppy_notification_policy => :to_s,
      :puppy_notification_frequency => :to_i,
      :puppy_last_notification => :jss_to_time,
      :puppy_reboot_policy => :to_s,

      :puppy_notify_image_path => :to_s,
      :puppy_optout_seconds => :to_i,
      :puppy_optout_text => :to_s,
      :puppy_optout_image_path => :to_s,
      :puppy_slideshow_folder_path => :to_s,
      :puppy_display_captions => :jss_to_bool,
      :puppy_no_captions_text => :to_s,
      :puppy_image_size => :to_i,
      :puppy_title => :to_s,
      :puppy_display_secs => :to_i,

      :notification_image_path => :jss_to_pathname,

      :admin_make_live_script => :to_s,
      :admin_auto_clean =>  :jss_to_bool,
      :admin_auto_clean_keep_deprecated => :to_i,
      :admin_auto_clean_keep_latest_pilots => :jss_to_bool,

      :report_receipts_ext_attr_name => :to_s,
      :report_puppyq_ext_attr_name => :to_s,
      :report_db_server => :to_s
    }

    ############### Attributes #################

    # automatically create accessors for all the CONF_KEYS
    CONF_KEYS.keys.each {|k| attr_accessor k}


    ############### Constructor #################

    #
    # Initialize!
    #
    def initialize
      read_conf
    end

    ############### Public Instance Methods #################

    # Since config must be loaded before logging can start
    # use this to send debug messages to stderr before
    # the logger is set up, if the client app has set debugging
    #
    #
    def log (msg, level)
      if D3.respond_to? :loaded? and D3.loaded?
         D3.log msg, level
      else
        STDERR.puts "#{level}: #{msg}" if ENV['D3_DEBUG']
      end
    end

    # Clear all values
    #
    # @return [void]
    #
    def clear_all
      log "Clearing all config values", :debug unless @initializing
      CONF_KEYS.keys.each {|k| self.send "#{k}=".to_sym, nil}
    end


    # (Re)read the global prefs, if it exists.
    #
    # @return [void]
    #
    def read_conf
      read CONF_FILE if CONF_FILE.file? and CONF_FILE.readable?
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
      read_conf
      return true
    end

    # Save the prefs into a file.
    #
    # @param file[String,Pathname]  an arbitrary file into which the config is saved.
    #   defaults to CONF_FILE
    #
    # @return [void]
    #
    def save(file = CONF_FILE)

      file = Pathname.new file

      # file already exists? read it in and update the values.
      if file.readable?
        data = file.read

        # go thru the known attributes/keys
        CONF_KEYS.keys.sort.each do |k|

          savable_value = to_string k

          # if the key exists, update it.
          if data =~ /^#{k}:/
            log "Updating config file value #{k}: #{savable_value}", :debug
            data.sub!(/^#{k}:.*$/, "#{k}: #{savable_value}")

          # if not, add it to the end unless it's nil
          else
            log "Adding config file value #{k}: #{savable_value}", :debug
            data += "\n#{k}: #{savable_value}" unless self.send(k).nil?
          end # if data =~ /^#{k}:/
        end #each do |k|

      else # not readable, make a new file
        data = ""
        log "Config file #{file} not found, creating.", :debug
        CONF_KEYS.keys.sort.each do |k|
          data << "#{k}: #{savable_value}\n" unless self.send(k).nil?
        end
      end # if path readable

      # make sure we end with a newline, the save it.
      data << "\n" unless data.end_with?("\n")
      file.jss_save data
      log "Config file #{file} saved.", :debug
    end # read file

    #
    # Print out the current settings to stdout
    #
    # @return [void]
    #
    def print
      CONF_KEYS.keys.sort.each{|k| puts "#{k}: #{to_string k}"}
    end

    ############### Private Instance Methods #################
    private

    # Convert an attribute value to a savable string.
    # All values are converted to Strings using a matching '_to_s'
    # private method, if defined, or with standard #to_s.
    #
    # @param key[symbol] one of the attribute keys from CONF_KEYS
    #
    # @return [String] a string version of teh attribute value
    #
    def to_string (key)
      # custom convertion to savable string?
      convert = (key.to_s + '_to_s').to_sym
      if self.class.private_method_defined? convert
        str = self.send convert
      else
        str = self.send(key).to_s
      end
      str
    end

    # Custom string conversion for the :client_prohibited_admin_names
    # value, which is an array.
    #
    # @return [String,nil] the Array values joined with commas, or nil
    #
    def client_prohibited_admin_names_to_s
      return nil unless @client_prohibited_admin_names
      @client_prohibited_admin_names.join ","
    end

    #
    # Read in any prefs file
    #
    # @param file[String,Pathname] the file to read
    #
    # @return [void]
    #
    def read(file)
      log "Reading config file #{file}", :debug

      Pathname.new(file).read.each_line do |line|
          # skip blank lines and those starting with #
          next if line =~ /^\s*(#|$)/

          line.strip =~ /^(\w+?):\s*(\S.*)$/
          next unless $1
          attr = $1.to_sym
          setter = "#{attr}=".to_sym
          value = $2.strip

          if CONF_KEYS.keys.include? attr
            if value
              # convert the value to the correct class
              # using the method from CONF_KEYS
              value = value.send *CONF_KEYS[attr]
            end
            self.send(setter, value)
            log "Set key '#{attr}' to '#{value}'", :debug
          end  # if
        end # do line

    end # read file

  end # class Configuration

  # The single instance of Configuration
  # must be created before the LOG, since
  # the log looks here for file names
  CONFIG = D3::Configuration.instance


end # module D3
