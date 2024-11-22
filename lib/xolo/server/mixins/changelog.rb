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
      # Each title has a changelog file that records changes to the title and its versions.
      #
      # The changelog file is a 'jsonlines' file, which is a JSON file containing
      # a single JSON object per line. See https://jsonlines.org/ for more info.
      # The reason for using jsonlines is that it is easy to append to the file, rather than
      # having to read the whole file into memory, parse it, add a new entry, and write it back.
      #
      # In this case, each line is a JSON object (ruby Hash) representing a change or an action.
      #
      # The keys in the hash are:
      #   :time - the time the change was made
      #   :admin - the admin who made the change
      #   :host - the hostname or IP address of the admin
      #   :version - the version number, or nil if the change is to the title
      #   :attrib - the attribute name, or nil if the change is an action
      #   :old - the original value, or nil if the change is an action
      #   :new - the new value, or nil if the change is an action
      #   :action - a description of the action, or nil if the change is to an attribute
      #
      # The changelog file is stored in the title directory in a file named 'changelog.json'.
      # The file exists for as long as the title exists.
      # It is backed up when before every event logged to it, in the backup directory in
      # the server's BACKUPS_DIR.
      #
      # When a title is deleted, its changelog file is moved to a backup directory before
      # the title directory is deleted, and will remain there until manually removed.
      #
      module Changelog

        # Constants
        #######################
        #######################

        # The change log filename
        TITLE_CHANGELOG_FILENAME = 'changelog.jsonl'

        # Module Methods
        #######################
        #######################

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # When a title is deleted, its changelog is moved to this directory and
        # renamed to '<title>_changelog.json'
        # This is so that the changelog can be accessed after the title is deleted.
        ################
        def self.backup_file_dir
          @backup_file_dir ||= Xolo::Server::BACKUPS_DIR + 'changelogs'
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
          @changelog_backup_file ||= Xolo::Server::Mixins::Changelog.backup_file_dir + "#{title}-#{TITLE_CHANGELOG_FILENAME}"
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
          changelog_data = []

          if changelog_file.exist?
            changelog_lock.with_read_lock do
              changelog_file.read.lines.each { |l| changelog_data << JSON.parse(l, symbolize_names: true) }
            end
          end

          changelog_data
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

          if changelog_backup_file.exist?
            # if deleting the whole title
            # move aside any previously existing one, appending a timestamp
            if self.class == Xolo::Server::Title && deleting?
              changelog_backup_file.rename "#{changelog_backup_file.basename}.#{changelog_backup_file.mtime.strftime('%Y%m%d%H%M%S')}"

              # otherwise, overwrite the current backup
            else
              changelog_backup_file.delete
            end

          end
          changelog_file.pix_cp changelog_backup_file
        end

        # Log a change by adding an entry to the changelog file for a title
        # or one of its versions.
        #
        # The entry may be for an message, such as 'Title Created',
        # or for a change to the value of an attribute.
        #
        # Provide either a message to log with :msg,
        # or the name of an attribute being changed, with :attrib,
        # and either :old_val, :new_val, or both.
        # (either can be omitted or set to nil, when adding or removing the attribute)
        #
        # @param attrib [Symbol] the attribute name
        # @param old_val [Object] the original value
        # @param new_val [Object] the new value
        # @param msg [String] an arbitrary message to log
        #
        # @return [void]
        #######################
        def log_change(attrib: nil, old_val: nil, new_val: nil, msg: nil)
          raise ArgumentError, 'Must provide attrib: or action:' if !msg && !attrib
          raise ArgumentError, 'Must provide old: or new: or both with attrib:' if attrib && (!old_val && !new_val)

          # if action, attrib, old, and new are ignored
          attrib, old_val, new_val = nil if msg

          change = {
            time: Time.now,
            admin: session[:admin],
            host: hostname_from_ip(server_app_instance.request.ip),
            version: respond_to?(:version) ? version : nil,
            msg: msg,
            attrib: attrib,
            old: old_val,
            new: new_val
          }

          log_debug "Writing to changelog for #{title}"

          changelog_lock.with_write_lock do
            backup_changelog
            changelog_file.pix_append "#{change.to_json}\n"
          end
        end

        # get a hostname from an IP address if possible
        #
        # @param ip [String] the IP address
        #
        # @return [String] the hostname or the IP address if the hostname cannot be found
        #######################
        def hostname_from_ip(ip)
          # gethostbbaddr is deprecated, so use Resolv instead
          # host = Socket.gethostbyaddr(ip.split('.').map(&:to_i).pack('CCCC')).first

          host = Resolv.getname(ip)

          host.pix_empty? ? ip : host
        rescue Resolv::ResolvError
          ip
        end

        # At the start of an update, populate the hash for the @changes_for_update attribute
        # with the changes being made.
        #
        # This is run at the start of the update process, and
        #
        # @return [Hash] The changes being made
        def note_changes_for_update_and_log
          return unless new_data_for_update

          changes = {}

          self.class::ATTRIBUTES.each do |attr, deets|
            next unless deets[:changelog]

            new_val = deets[:type] == :time ? Time.parse(new_data_for_update[attr]) : new_data_for_update[attr]
            old_val = send attr

            # Don't change arrays to strings!
            # just sort them to compare
            new_val_to_compare =  new_val.is_a?(Array) ? new_val.sort : new_val
            old_val_to_compare =  old_val.is_a?(Array) ? old_val.sort : old_val
            next if new_val_to_compare == old_val_to_compare

            changes[attr] = { old: old_val, new: new_val }
          end

          changes
        end

        # Record all changes during an update of a title or version
        #
        # @return [void]
        #######################
        def log_update_changes
          return unless changes_for_update

          # self.class::ATTRIBUTES.each do |attr, deets|
          #   next unless deets[:changelog]

          #   new_val = deets[:type] == :time ? Time.parse(new_data_for_update[attr]) : new_data_for_update[attr]
          #   old_val = send attr

          #   new_val = "'#{new_val.sort.join("', '")}'" if new_val.is_a? Array
          #   old_val = "'#{old_val.sort.join("', '")}'" if old_val.is_a? Array
          #   next if new_val == old_val

          #   log_change attrib: attr, old_val: old_val, new_val: new_val
          # end

          changes_for_update.each do |attr, vals|
            log_change attrib: attr, old_val: vals[:old], new_val: vals[:new]
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
            host: hostname_from_ip(server_app_instance.request.ip),
            version: nil,
            action: 'Title Deleted',
            attrib: nil,
            old: nil,
            new: nil
          }

          changelog_lock.with_write_lock do
            changelog_file.pix_append "#{change.to_json}\n"

            # final backup
            changelog_backup_file.delete if changelog_backup_file.exist?
            changelog_file.rename changelog_backup_file
          end
        end

      end # Changelog

    end # Mixins

  end # Server

end # module Xolo
