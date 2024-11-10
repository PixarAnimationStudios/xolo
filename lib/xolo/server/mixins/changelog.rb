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

  module Server

    module Mixins

      # This is mixed in to Xolo::Server::Title and Xolo::Server::Version,
      # for simplified access to a title's changelog
      #
      module Changelog

        # The change log filename for this title and its versions
        # It is stored in the title dir in a file with this name.
        # It contains a JSON array of hashes, each hash representing
        # a change to the title or one of its versions.
        # the hashes have keys: :time, :admin, :ipaddr, :version (may be nil), :old, :new
        TITLE_CHANGELOG_FILENAME = 'changelog.json'

        # When a title is deleted, its changelog is moved to this directory and
        # renamed to '<title>_changelog.json'
        # This is so that the changelog can be accessed after the title is deleted.
        ################
        def self.backup_file_dir
          @backup_file_dir ||= Xolo::Server::BACKUPS_DIR + 'changelogs'
        end

        # Module Methods
        #######################
        #######################

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # A hash of the read-write locks for each title's changelog file
        # The key is the title name, the value is the Concurrent::ReentrantReadWriteLock
        # instance for that title.
        #
        # Titles and versions use these locks to ensure that only one
        # thread at a time can write to a title's changelog file.
        #
        # @return [Concurrent::Hash] the locks
        def self.changelog_locks
          @changelog_locks ||= Concurrent::Hash.new
        end

        # Instance Methods
        #######################
        #######################

        # the change log file for a title
        #
        # @param title [String] the title
        #
        # @return [Pathname] the path to the file
        #######################
        def changelog_file
          @changelog_file ||= Xolo::Server::Title.title_dir(title) + TITLE_CHANGELOG_FILENAME
        end

        # @return [Pathname] the path to the backup file for this title's changelog
        #######################
        def changelog_backup_file
          @changelog_backup_file ||= Xolo::Server::Mixins::Changelog.backup_file_dir + "#{title}-changelog.json"
        end

        # the read-write lock for a title's changelog file
        #
        # @param title [String] the title
        #
        # @return [Concurrent::ReentrantReadWriteLock] the lock
        #######################
        def changelog_lock
          @changelog_lock ||=
            if Xolo::Server::Mixins::Changelog.changelog_locks[title]
              Xolo::Server::Mixins::Changelog.changelog_locks[title]
            else
              log_debug "Creating changelog lock for #{title}"
              Xolo::Server::Mixins::Changelog.changelog_locks[title] = Concurrent::ReentrantReadWriteLock.new
            end
        end

        # the change log for a title
        #
        # @return [Array<Hash>] the changelog
        #######################
        def changelog
          log_debug "Reading changelog for #{title}"
          if changelog_file.exist?
            changelog_lock.with_read_lock { JSON.parse changelog_file.read, symbolize_names: true }
          else
            []
          end
        end

        # Copy the changelog file to the backup directory
        #
        # @return [void]
        #######################
        def backup_changelog
          return unless changelog_file.exist?

          unless changelog_backup_file.dirname.exist?
            log_debug 'Creating backup directory for changelogs'
            changelog_backup_file.dirname.mkpath
          end

          log_debug "Backing up changelog for #{title}"
          changelog_backup_file.delete if changelog_backup_file.exist?
          changelog_file.pix_cp changelog_backup_file
        end

        # Add a change to the changelog file for a title
        #
        # @param old [Object] the original value
        # @param new [Object] the new value
        #
        # @return [void]
        #######################
        def log_change(old:, new:)
          change = {
            time: Time.now,
            admin: session[:admin],
            ipaddr: server_app_instance.request.ip,
            version: respond_to?(:version) ? version : nil,
            old: old,
            new: new
          }

          log_debug "Writing to changelog for #{title}"

          changelog_lock.with_write_lock do
            backup_changelog
            all_changes = changelog
            all_changes << change
            changelog_file.pix_save JSON.pretty_generate(all_changes)
          end
        end

        # Record all changes during an update of a title or version
        #
        # @return [void]
        #######################
        def log_update_changes
          return unless new_data_for_update

          self.class::ATTRIBUTES.each do |attr, deets|
            next unless deets[:changelog]

            new_val = deets[:type] == :time ? Time.parse(new_data_for_update[attr]) : new_data_for_update[attr]
            old_val = send attr

            new_val = "'#{new_val.sort.join("', '")}'" if new_val.is_a? Array
            old_val = "'#{old_val.sort.join("', '")}'" if old_val.is_a? Array
            next if new_val == old_val

            log_change old: old_val, new: new_val
          end
        end

        # when a title is deleted, make a final entry, then
        # move its changelog to the backup directory
        #
        # @return [void]
        #######################
        def delete_changelog
          change = {
            time: Time.now,
            admin: session[:admin],
            ipaddr: server_app_instance.request.ip,
            version: nil,
            old: nil,
            new: 'Deleted Title'
          }

          changelog_lock.with_write_lock do
            all_changes = changelog
            all_changes << change
            changelog_file.pix_save JSON.pretty_generate(all_changes)

            changelog_backup_file.delete if changelog_backup_file.exist?
            changelog_file.rename changelog_backup_file
          end
        end

      end # Changelog

    end # Mixins

  end # Server

end # module Xolo
