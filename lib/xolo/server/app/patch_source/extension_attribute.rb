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

module Xolo

  # A PatchManagement Extension Attribute.
  #
  # This defines a script-based extension attribute to be used in Patch
  # Policy eligibility scoping.
  #
  # It is similar to a regular ComputerExtensionAttribute, but the data is
  # gathered separately from regular EAs and is used behind the scenes
  # by the JSS to calculate patch eligibility.
  #
  # If a title includes any of these, they must be approved by a JamfPro
  # admin in the web ui before they will be activated.
  #
  class ExtensionAttribute

    DATA_DIR = Xolo::Server::Config::SUPPORT_DIR + 'extension-attributes'

    # A Hash of every Xolo::ExtensionAttribute instance in d3, keyed by name
    #
    #   {
    #     'ea_name' => Xolo::ExtensionAttribute,
    #     'ea_name' => Xolo::ExtensionAttribute,
    #     'ea_name' => Xolo::ExtensionAttribute,
    #     ...
    #   }
    #
    # This is the in-memory data store for the d3 server.
    # Data is only ever read from disk when the server starts up. After that
    # changes made in memory and are written to disk, but all data sent to
    # clients comes from memory.
    #
    def self.data_store
      @data_store ||= load_data_store
    end

    # used when writing data store changes to memory and disk
    def self.data_store_semaphore
      @data_store_semaphore ||= Mutex.new
    end

    # Load in the titles from disk
    def self.load_data_store
      DATA_DIR.mkpath
      data_store_semaphore.synchronize do
        @data_store = {}
        DATA_DIR.children.each do |item|
          next unless item.extname == Xolo::DOT_YML
          name = item.basename.to_s.chomp Xolo::DOT_YML
          @data_store[name] = item.d3_load_yaml
        end # do item
        refresh_json_summary_list
      end # semaphore sync
      @data_store
    end

    # A JSON Array of Strings, the unique names of the extensionAttributes
    # This is passed to clients when they GET the ../ext_attrs route.
    #
    def self.json_summary_list
      @json_summary_list ||= refresh_json_summary_list
    end

    def self.refresh_json_summary_list
      @json_summary_list = data_store.keys.to_json
    end

    # get one Title instance by name
    def self.fetch(name)
      validate_ea_exists(name)
      data_store[name]
    end

    # TODO: more json validation?
    def self.new_from_client_json(rawjson)
      new from_json: JSON.parse(rawjson, symbolize_names: true)
    end

    # Raise error if given title name doesn't exist
    def self.validate_ea_exists(name)
      raise JSS::NoSuchItemError, "No ExtensionAttribute matching #{name}" unless data_store.key? name
    end

    # raise error if given title name does exist
    def self.validate_unique_name(name)
      raise JSS::AlreadyExistsError, "An ExtensionAttribute with name '#{name}' already exists" if data_store.key? name
    end

    def create
      validate_unique_name
      self.class.data_store_semaphore.synchronize do
        @created_at = Time.now
        @last_modified = @created_at
        disk_file.d3_atomic_write to_yaml
        self.class.data_store[name] = self
        self.class.refresh_json_summary_list
      end # semphore sync
      :created
    end

    def update
      validate_ea_exists
      self.class.data_store_semaphore.synchronize do
        @last_modified = Time.now
        disk_file.d3_atomic_write to_yaml
        self.class.data_store[name] = self
        self.class.refresh_json_summary_list
      end # semphore sync
      :updated
    end

    def delete
      self.class.data_store_semaphore.synchronize do
        disk_file.delete if disk_file.file?
        self.class.data_store.delete name
        self.class.refresh_json_summary_list
      end # semphore sync
      :deleted
    end

    def validate_ea_exists
      self.class.validate_title_exists name
    end

    def validate_unique_name
      self.class.validate_unique_name name
    end

    def disk_file
      @disk_file ||= DATA_DIR + "#{name}#{Xolo::DOT_YML}"
    end

    def to_yaml
      YAML.dump self
    end

    # used by the D3 PatchSource to pass to the JSS
    def patch_source_data
      {
        key: name,
        value: code,
        displayName: display_name
      }
    end

  end # class ExtensionAttribute

end # module Xolo
