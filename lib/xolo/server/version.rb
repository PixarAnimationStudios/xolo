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

module Xolo

  module Server

    # A version available in a title in d3.
    #
    # This file defines methods and values used only on the server
    #
    class Version < Xolo::AbstractVersion

      # Constants
      ######################################

      # the standard fields returned via get '/'
      DFT_SUMMARY_FIELDS = %i[
        id
        added_date
        title
        version
        status
        package_id
      ].freeze

      # Class Attributes
      class << self

        # @return [Concurrent::Map]
        attr_reader :data_store

        # @return [Concurrent::AtomicFixnum]
        attr_reader :max_id

      end

      # Load in the titles from disk
      # This must happen before the server starts running.
      #
      # A 2-tiered Hash of every Xolo::Server::Version instance in d3
      # keyed by title name and then version string.
      #
      #   {
      #     'title_name' => {
      #       'version_string' => Xolo::Server::Version,
      #       'version_string2' => Xolo::Server::Version,
      #       ...
      #     }
      #     'title_name2' => {
      #       'version_string3' => Xolo::Server::Version,
      #       'version_string4' => Xolo::Server::Version,
      #       ...
      #     }
      #    ...
      #   }
      #
      # This is the in-memory data store for the d3 server.
      #
      # Data is only ever read from disk by this method, when the server starts
      # up. After that changes made in memory and are written to disk, but all
      # data sent to clients comes from memory.
      #
      # The data is in a thread-safe hash-like object called Concurrent::Map
      # see https://github.com/ruby-concurrency/concurrent-ruby for details
      #
      # The max_id is thread-safe, atomically updated integer from the
      # same library called Concurrent::AtomicFixnum.
      #
      def self.load_data_store
        return if @data_store
        @data_store = Concurrent::Map.new
        @max_id = Concurrent::AtomicFixnum.new
        Xolo.logger.debug 'Loading Version data-store'
        Xolo::Server::Title.data_dir.children.each do |item|
          next unless item.directory?
          title_name = item.basename.to_s
          @data_store[title_name] = Concurrent::Map.new
          item.children.each do |versfile|
            vers = versfile.d3_load_yaml
            @data_store[title_name][vers.version] = vers
            @max_id.value = vers.id if vers.id > @max_id.value
            Xolo.logger.debug "Loaded version '#{vers.version}' for title '#{title_name}'"
          end # each versfile
        end # Xolo::Server::Title.data_dir.children.each do |item|
        Xolo.logger.info 'Version data-store loaded'
        refresh_json_summary_list
      end # load_data_store

      # Should only be called by #create
      def self.add_version_to_data_store(vers)
        validate_unique_version vers.title, vers.version
        vers.disk_file.d3_atomic_write vers.to_yaml
        @data_store[vers.title] ||= {}
        @data_store[vers.title][vers.version] = vers
        Xolo.logger.debug "Version added to data-store: title: #{vers.title}, vers: #{vers.version}"
        refresh_json_summary_list
      end

      # Should only be called by #update
      def self.update_version_in_data_store(vers)
        validate_version_exists vers.title, vers.version
        vers.disk_file.d3_atomic_write vers.to_yaml
        @data_store[vers.title][vers.version] = vers
        Xolo.logger.debug "Version updated in data-store: title: #{vers.title}, vers: #{vers.version}"
        refresh_json_summary_list
      end

      # Should only be called by #delete
      def self.delete_version_from_data_store(vers)
        vers.disk_file.delete if vers.disk_file.file?
        return unless @data_store[vers.title]
        @data_store[vers.title].delete vers.version
        Xolo.logger.debug "Version deleted from data-store: title: #{vers.title}, vers: #{vers.version}"
        refresh_json_summary_list
      end

      # delete all versions for a title
      # This is called when titles themselves are deleted.
      def self.delete_all_for_title(title_name)
        return unless @data_store[title_name]
        Xolo.logger.debug "Deleting all Versions from data-store for title: #{title_name}"
        # delete the yml files
        @data_store[title_name].values.each do |vers|
          vers.disk_file.delete if vers.disk_file.file?
        end
        @data_store.delete title_name
        Xolo.logger.debug "Deleted all Versions from data-store for title: #{title_name}"
        refresh_json_summary_list
      end

      # the next available id number
      def self.next_id
        @max_id.increment
      end

      # A JSON Array of Hashes, one per version
      # This is passed to clients when they GET the ../versions route.
      # See #summary_hash for the hash keys
      #
      def self.json_summary_list
        @json_summary_list || refresh_json_summary_list
      end

      # refresh the json_summary_list
      def self.refresh_json_summary_list
        new_list = []
        @data_store.values.each do |hsh|
          next if hsh.empty?
          new_list += hsh.values.map(&:summary_hash)
        end
        @json_summary_list = new_list.to_json
        Xolo.logger.debug 'Version json summary list refreshed'
        @json_summary_list
      end

      # A summary list with custom fields
      def self.custom_summary_list(fields)
        fields = fields.split(/\s*,\s*/).map(&:to_sym)
        list = []
        @data_store.values.each do |hsh|
          next if hsh.empty?
          list += hsh.values.map { |v| v.summary_hash(fields) }
        end
        Xolo.logger.debug "Processed custom Version summary list with fields: #{fields}"
        list.to_json
      end

      # get one Version instance from the data store.
      # always clear any possibly residual changes
      def self.fetch(title, version)
        validate_version_exists(title, version)
        @data_store[title][version].changes.clear
        @data_store[title][version]
      end

      # TODO: more json validation?
      def self.new_from_client_json(rawjson)
        new from_json: JSON.d3parse(rawjson)
      end

      # Should only be called by #release
      #
      # @param version_to_release[Xolo::Server::Version]
      #
      def self.release(version_to_release, admin)
        versions_for_title = @data_store[version_to_release.title]

        # Update the status of all versions of this title.
        # This loop should be threadsafe cuz
        # @data_store[title] is a Concurrent::Map
        versions_for_title.each do |vers|
          # don't save to disk if not needed
          save_vers = false

          # mark this one as released
          if vers.id == version_to_release.id
            vers.status = STATUS_RELEASED
            vers.released_by = admin
            vers.release_date = Time.now
            save_vers = true

          # if the version is older than the new release
          elsif vers.id < version_to_release.id
            vers.status =
              case vers.status
              # pilots become skipped
              when STATUS_PILOT
                save_vers = true
                STATUS_SKIPPED
              # releases become deprecated
              when STATUS_RELEASED
                save_vers = true
                STATUS_DEPRECATED
              end # case

          # if the version is newer than the new release,
          # we might be rolling back, so it becomes a pilot
          # again if it isn't already.
          elsif vers.id > version_to_release.id
            next if vers.status == STATUS_PILOT
            vers.status = STATUS_PILOT
            save_vers = true
          end # if elsif

          # save to disk
          vers.disk_file.d3_atomic_write vers.to_yaml if save_vers
        end # each do vers

        # Update the title
        Xolo::Server::Title.fetch(version_to_release.title).released_version = version_to_release.version

        # TODO: autocleaning
        # Delete all skipped versions and all but the latest X deprecated versions
      end

      # raise error if a given version doesn't exist for a given title
      def self.validate_version_exists(title, version)
        raise JSS::NoSuchItemError, "No version '#{version}' for title #{title}" unless version_exist?(title, version)
      end

      # raise error if a given version exists for a given title
      def self.validate_unique_version(title, version)
        raise JSS::AlreadyExistsError, "Version '#{version}' already exists for title '#{title}'" if version_exist?(title, version)
      end

      def self.version_exist?(title, version)
        @data_store.key?(title) && @data_store[title].key?(version)
      end

      # Instance Attributes
      ################################

      # readers & writers used by the server
      attr_reader :changes
      attr_writer :status
      attr_writer :released_by
      attr_writer :release_date

      # Instance Methods
      #################################

      # turn the changes hash into a changelog message
      #
      # @return [String]
      #
      def changes_to_log
        msg_parts = []
        @changes.each do |attr, vals|
          next if vals[:orig] == vals[:new]
          msg_parts << "#{attr} '#{vals[:orig]}' -> '#{vals[:new]}'"
        end # each do |attr, vals|
        msg_parts.join '; '
      end # changes to log

      # create this version in d3 by adding to data store and
      # saving to disk
      def create(admin)
        self.class.validate_unique_version(title, version)
        @id = self.class.next_id
        @added_date = Time.now
        @added_by = admin

        self.class.add_version_to_data_store self
        Xolo::Server::Title.fetch(title).latest_version = version
        Xolo::Server::Title.update_changelog title, admin, "Created version '#{@version}'; #{changes_to_log}"

        @changes.clear
        :created
      end

      def update(admin)
        @last_modified = Time.now
        @modified_by = admin
        changes_to_log = @changes.join('; ')
        @changes.clear
        self.class.update_version_in_data_store(self)
        Xolo::Server::Title.update_changelog title, admin, "Updated version '#{@version}'; #{changes_to_log}"

        @changes.clear

        :updated
      end

      # TODO: investigate what has to happen in the JSS when we do this to
      # a title that we source.
      def delete
        self.class.delete_version_from_data_store(self)
        Xolo::Server::Title.update_changelog title, admin, "Deleted version '#{@version}'; #{@changes.join('; ')}"
        :deleted
      end # delete

      def release(admin)
        return nil if @status == STATUS_RELEASED
        self.class.release self, admin
      end

      def disk_version_dir
        Xolo::Server::Title.data_dir + title
      end

      def disk_file
        @disk_file ||= disk_version_dir + "#{version}#{Xolo::DOT_YML}"
      end

      def to_yaml
        YAML.dump self
      end

      # The values returned in the summary list hash for a version.
      def summary_hash(fields = DFT_SUMMARY_FIELDS)
        summ = {}
        fields.unshift :id unless fields.include? :id
        fields.each { |f| summ[f] = send f if respond_to? f }
        summ
      end

      ####### PatchSource server data

      def patch_source_json
        patch_source_data.to_json
      end

      def patch_source_data
        {
          version: version,
          releaseDate: added_date.iso8601,
          standalone: (standalone ? true : false),
          minimumOperatingSystem: minimum_os_for_patch,
          reboot: reboot_required,
          killApps: kill_apps,
          components: client_components.map(&:patch_source_data),
          capabilities: client_capability_criteria.patch_source_data,
          dependencies: []
        }
      end # patch_source_json

      def component_source_data
        {
          name: title.name,
          version: version,
          criteria: client_components.patch_source_data
        }
      end

    end # class Version

  end # module Server

end # module Xolo
