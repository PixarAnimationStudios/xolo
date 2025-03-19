# Copyright 2025 Pixar
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

# main module
module Xolo

  # Server Module
  module Server

    # Code for locking titles and versions as they are being modified
    ##################################
    module ObjectLocks

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # when this module is extended
      def self.extended(extender)
        Xolo.verbose_extend extender, self
      end

      # How many seconds are update locks valid for?
      OBJECT_LOCK_LIMIT = 60 * 60

      # The locks for titles and versions - when they are being created or updated
      # they appear in this data structure with an expiration timestamp.
      # During that time, no other updates can be made to the same title or version.
      #
      # Keys are the title names, values are hashes with these sub-keys:
      # - expires: the time the title lock expires, time locked plus OBJECT_LOCK_LIMIT
      # - versions: Hash of versions_that_are_locked => expiration_time
      #
      # @return [Concurrent::Hash] The locks
      ################################
      def object_locks
        @object_locks ||= Concurrent::Hash.new
      end

      # Remove any expired locks from the object_locks
      ################################
      def remove_expired_object_locks
        now = Time.now

        # first delete any expired version locks
        object_locks.each_value do |locks|
          locks[:versions] ||= {}

          locks[:versions].delete_if do |vers, exp|
            if exp < now
              log_debug "Removing expired lock on version #{vers} of title #{title}"
              true
            else
              false
            end
          end
        end

        # now delete any expired title locks that have no versions locked
        object_locks.delete_if do |_title, locks|
          # keep it if there are versions locked
          if !locks[:versions].empty?
            false

          # if there's a title lock expiration time, check it
          elsif locks[:expires]
            if locks[:expires] < now
              log_debug "Removing expired lock on title #{title}"
              true
            else
              false
            end

          # no title-lock expiration time
          else
            true
          end
        end
      end

      # Testing Concurrent::ReentrantReadWriteLock for titles and versions
      # to be acquired and released in the route blocks
      #
      def rw_lock(title, version = nil)
        @rw_locks ||= Concurrent::Hash.new
        @rw_locks[title] ||= { lock: Concurrent::ReentrantReadWriteLock.new }
        return @rw_locks[title] unless version

        @rw_locks[title][version] ||= Concurrent::ReentrantReadWriteLock.new
      end

    end #  ObjectLocks

  end #  Server

end # module Xolo
