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

module D3

  module Server

    # Title on the d3 server
    class Title < D3::AbstractTitle

      # Constants
      ######################################

      # appended to title name for the
      # changelog file
      CHANGELOG = '-changelog'.freeze

      # the standard fields returned via get '/'
      DFT_SUMMARY_FIELDS = %i[
        name
        display_name
        released_version
        latest_version
        standard
        auto_group_ids
        excluded_group_ids
        jss_patch_source_id
        jss_id
        jss_name_id
      ].freeze


      # Class Attributes
      ######################################
      class << self

        # @return [Concurrent::Map]
        attr_reader :data_store

      end # class << self

      # The directory where title and version data is stored
      # BACK THIS UP!
      #
      def self.data_dir
        @data_dir ||= Pathname.new "#{D3::Server.config.data_dir}/titles"
        return @data_dir if @data_dir.exist?
        @data_dir.mkpath
        D3.logger.info "Created Title Data Directory '#{@data_dir}'"
        @data_dir
      end

      # Load in the titles from disk
      # This must happen before the server starts running.
      #
      # A Hash of every D3::Server::Title instance in d3, keyed by name
      #
      #   {
      #     'title_name' => D3::Server::Title,
      #     'title_name' => D3::Server::Title,
      #     'title_name' => D3::Server::Title,
      #     ...
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
      def self.load_data_store
        return if @data_store
        @changelog_locks ||= {}
        @data_store = Concurrent::Map.new
        D3.logger.debug 'Loading Title data-store'
        data_dir.children.each do |item|
          next if item.basename.to_s.include? CHANGELOG
          next unless item.extname == D3::DOT_YML
          name = item.basename.to_s.chomp D3::DOT_YML
          @data_store[name] = item.d3_load_yaml
          D3.logger.debug "Loaded title '#{name}'"
        end # do item
        D3.logger.info 'Title data-store loaded'
        refresh_json_summary_list
      end

      def self.add_title_to_data_store(title)
        title.disk_version_dir.mkpath
        title.disk_file.d3_atomic_write title.to_yaml
        @data_store[title.name] = title
        D3.logger.debug "Title added to data-store: #{title.name}"
        refresh_json_summary_list
      end

      def self.update_title_in_data_store(title)
        title.disk_file.d3_atomic_write title.to_yaml
        @data_store[title.name] = title
        D3.logger.debug "Title updated in data-store: #{title.name}"
        refresh_json_summary_list
      end

      def self.delete_title_from_data_store(title)
        Version.delete_all_for_title(title.name)
        title.disk_file.delete if title.disk_file.file?
        title.disk_version_dir.rmtree if title.disk_version_dir.directory?
        title.disk_changelog_file.delete if title.disk_changelog_file.file?
        @data_store.delete title.name
        D3.logger.debug "Title deleted from data-store: #{title.name}"
        refresh_json_summary_list
      end

      # changelogs aren't stored as attributes of title objects
      # cuz the actual Title instance stored in the data store
      # is replaced when updated, making it tough to ensure
      # validity of the changelog.
      # So, each title has a changelog.yml file.
      #
      # Changes to versions are stored in the title's changelog
      # and Version objects call this method on their title as needed
      #
      # @param title[String] Unique name of a D3::Server::Title
      # @param admin[String]
      # @param msg[String]
      # @return [void]
      #
      def self.update_changelog(titlename, admin, msg)
        validate_title_exists titlename
        @changelog_locks[titlename] ||= Mutex.new
        @changelog_locks[titlename].synchronize do
          file = @data_store[titlename].disk_changelog_file
          chlog = file.file? ? file.d3_load_yaml : []
          chlog << { timestamp: Time.now, admin: admin, msg: msg }
          file.d3_atomic_write YAML.dump(chlog)
        end # sync
        D3.logger.debug "Updated changelog for title '#{titlename}'"
      end # update_changelog

      # GETting the collection resource ../titles returns a JSON Array of
      # summary Hashes, one per title. A standard array is kept in memory
      # and updated as needed, heavily used by d3 client. A list with
      # custom fields can be retrieved by providing a request param
      # 'fields' with a comma-separated list of desired attributes in
      # each hash.
      #
      # Without custom fields each title hash has these fields/keys
      #   - name: the unique name of this title in d3, only alphanumerics & _
      #   - display_name: A more human-friendly, flexible name,
      #   - released_version: the version number of the currently live version
      #   - latest_version: the version number of the latest version
      #   - standard: should this title be installed on all machines automatically
      #   - auto_group_ids: (array) the jss id's of computer groups that should have
      #     this installed automatically
      #   - excluded_group_ids: (array) the jss id's of computer groups that should
      #     not be able to install this title without force
      #   - jss_patch_source_id: the JSS::PatchSource id, which could be that of d3.
      #   - jss_id: the JSS id of the title, nil if not activated in the JSS
      #   - jss_name_id: the JSS name_id of the title, same as name if d3 is the source
      # With custom fields, the requested fields are returned, plus :name
      # if it wasn't requested
      #

      # The standard summary list, kept in memory
      # and updated as needed, heavily used by d3 client
      def self.json_summary_list
        @json_summary_list || refresh_json_summary_list
      end

      def self.refresh_json_summary_list
        @json_summary_list = @data_store.values.map(&:summary_hash).to_json
        D3.logger.debug 'Title json summary list refreshed'
        @json_summary_list
      end

      # A summary list with custom fields
      def self.custom_summary_list(fields)
        fields = fields.split(/\s*,\s*/).map(&:to_sym)
        list = []
        @data_store.values.each do |title|
          list << title.summary_hash(fields)
        end
        D3.logger.debug "Processed custom Title summary list with fields: #{fields}"
        list.to_json
      end

      # get one Title instance from the data store.
      # always clear any possibly residual changes
      def self.fetch(name)
        validate_title_exists(name)
        @data_store[name].changes.clear
        @data_store[name]
      end

      # TODO: more json validation?
      def self.new_from_client_json(rawjson)
        new from_json: JSON.d3parse(rawjson)
      end

      # @return [Hash<D3::Version>] all D3::Version instances for a given title,
      #   keyed by version string
      #
      def self.versions(name)
        validate_title_exists(name)
        D3::Version.data_store[name] || {}
      end

      # Raise error if given title name doesn't exist
      def self.validate_title_exists(name)
        raise JSS::NoSuchItemError, "No Title matching #{name}" unless title_exist?(name)
      end

      # raise error if given title name does exist
      def self.validate_unique_name(name)
        raise JSS::AlreadyExistsError, "A title with name '#{name}' already exists" if title_exist?(name)
      end

      def self.title_exist?(name)
        @data_store.key? name
      end

      # Changes to Versions are logged in the title's changelog.
      # Server::Versions call this method to log such a change
      #
      # @param vers[D3::Server::Version] the version being logged
      # @param admin[String] the admin making the change
      # @param message[String] the change message to log
      #
      # @return [void]
      #
      def self.log_a_version_change(vers, admin, msg)
        title = @data_store[vers.title]
        @data_store[vers.title].changelog[Time.now] = { admin: admin, msg: msg }
        @data_store[vers.title].disk_file.d3_atomic_write title.to_yaml
      end

      # Instance Methods
      #################################

      attr_reader :changes

      # called by Version#create on the server
      # TODO: validation
      def latest_version=(vers)
        @latest_version = vers
        self.class.update_title_in_data_store self
      end

      # called by Version#release on the server
      # TODO: validation
      def released_version=(vers)
        @released_version = vers
        self.class.update_title_in_data_store self
      end

      def summary_hash(fields = DFT_SUMMARY_FIELDS)
        summ = {}
        fields.unshift :name unless fields.include? :name
        fields.each { |f| summ[f] = send f if respond_to? f }
        summ
      end

      # Since the changelog files are written atomically, we don't
      # need to read them via a mutex.
      #
      def changelog_json
        chlog = disk_changelog_file.file? ? disk_changelog_file.d3_load_yaml : []
        # convert Time keys to iso8601 strings
        chlog.each { |change| change[:timestamp] = change[:timestamp].iso8601 }.to_json
      end

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

      def create(admin)
        validate_unique_name
        @added_date = Time.now
        @added_by = admin
        @last_modified = @added_date
        @modified_by = admin

        D3::Server::Title.add_title_to_data_store self
        D3::Server::Title.update_changelog name, admin, "Title Created; #{changes_to_log}"
        @changes.clear
        :created
      end

      def update(admin)
        return if @changes.empty?
        validate_title_exists
        @last_modified = Time.now
        @modified_by = admin

        D3::Server::Title.update_title_in_data_store self
        D3::Server::Title.update_changelog name, admin, "Title Updated; #{changes_to_log}"
        @changes.clear
        :updated
      end

      # TODO: when implementing Jamf Patch,
      # investigate what has to happen in the JSS when we do this to
      # a title that we source.
      def delete
        D3::Server::Title.delete_title_from_data_store self
        :deleted
      end

      def validate_title_exists
        D3::Server::Title.validate_title_exists name
      end

      def validate_unique_name
        D3::Server::Title.validate_unique_name name
      end

      # @return [Pathname] the on-disk representation of this title
      #
      def disk_file
        @disk_file ||= D3::Server::Title.data_dir + "#{name}#{D3::DOT_YML}"
      end

      # @return [Pathname] the on-disk representation of this title's
      #   changelog
      #
      def disk_changelog_file
        @disk_changelog_file ||= D3::Server::Title.data_dir + "#{name}#{CHANGELOG}#{D3::DOT_YML}"
      end

      # @return [Pathname] the directory containing the on-disk representations
      # of the versions of this title
      #
      def disk_version_dir
        @disk_version_dir ||= D3::Server::Title.data_dir + name
      end

      def to_yaml
        YAML.dump self
      end

      ####### PatchSource server data

      def patch_source_title_summary
        {
          name: name,
          publisher: publisher,
          lastModified: last_modified.iso8601,
          currentVersion: latest_version,
          id: name_id
        }.to_json
      end

      def patch_source_title
        {
          id: name_id,
          name: name,
          publisher: publisher,
          lastModified: last_modified.iso8601,
          currentVersion: latest_package.version,
          requirements: criteria.patch_source_json,
          patches: versions.map(&:patch_source_json),
          extensionAttributes: ext_attrs.map(&:patch_source_json)
        }.to_json
      end

    end # class title

  end # module server

end # modle D3
