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
  class Client < JSS::Client

    #
    # Receipt - a d3 package that is currently installed on this machine.
    #
    # D3 receipts are stored as their native ruby objects in a YAML file located at D3::Client::Receipt::DATASTORE
    #
    # When the module loads, the file is read if it exists and all receipts are available in
    #
    # The datastore contains a Hash of D3::Client::Receipt objects, keyed by their titles (only one
    # installation of a title can be on a machine at a time)
    #
    #
    #
    class Receipt

      ############### Mixin Modules #################

      include D3::Patch

      ############### Class Constants #################

      # This YAML file stores all D3::Client::Receipts on this machine
      DATASTORE = D3::SUPPORT_DIR + "receipts.yaml"

      # This locks the loading of receipts when there's a potential to
      # write them back ou.  See Receipt.load_receipts.
      DATASTORE_LOCKFILE = D3::SUPPORT_DIR + "receipts.lock"

      # How many seconds by default to keep trying to get the datastore lockfile.
      DATASTORE_LOCK_TIMEOUT = 10

      # If a lockfile is this many seconds old, warn that it might be stale and need
      # manual cleanup. 600 secs = 10 min
      DATASTORE_STALE_LOCK_AGE = 600

      # This plist contains the last time any app was brought to the
      # foreground. It's updated by the helper app d3RepoMan.app
      # which should always be running if expiration is turned on.
      #LAST_APP_USAGE_FILE =  D3::SUPPORT_DIR + "last-foreground-times.plist"

      # This dir contains a plist for each GUI user, containing
      # the last time any app was brought to the foreground for that user
      # It's updated by the helper app d3RepoMan.app
      # which should always be running while a GUI user is logged in
      # if expiration is turned on.
      LAST_APP_USAGE_DIR =  D3::SUPPORT_DIR + "Usage"

      # This is the process (as listed in the output of '/bin/ps -A -c -o comm')
      # that updates the LAST_APP_USAGE_FILE. If it isn't running as root
      # when expiration is attempted, then expiration won't happen.
      APP_USAGE_MONITOR_PROC = "d3RepoMan"

      # The newest of the  plists in the LAST_APP_USAGE_DIR must have been
      # updated within the last X number of seconds, or else we assume
      # either no one's logged in for a while, or something's wrong with the
      # usage monitoring, since nothing new has come to the foreground
      # in that long. If so, nothing will be expired.
      # Default is 24 hours
      MAX_APP_USAGE_UPDATE_AGE = 60 * 60 * 24

      # These args are required when creating a new D3::Client::Receipt
      REQUIRED_INIT_ARGS = [
        :title,
        :version,
        :revision,
        :admin,
        :id,
        :jamf_rcpt_file,
        :status
      ]

      # Only these attributes can be changed after a receipt is created
      CHANGABLE_ATTRIBS = [
        :status,
        :removable,
        :pre_remove_script_id,
        :post_remove_script_id,
        :expiration,
        :expiration_bundle_ids,
        :prohibiting_processes
      ]

      ################ Class Variables #################

      # The current receipts.
      # See D3::Client::Receipt.load_receipts and D3::Client::Receipt.all
      @@installed_rcpts = nil

      # Do we currently have the rw lock?
      @@got_lock = nil

      ############### Class Methods #################

      # Load in the existing rcpt database if it exists.
      # This makes them available in @@installed_rcpts and from
      # D3::Client::Receipt.all
      #
      # When loading read-write, if another process has loaded them read-write,
      # and hasn't saved them yet, a lock file will be present and this load
      # will retry for lock_timeout seconds before raising an exception
      #
      # @param rw[Boolean] Load the receipts read-write, meaning that a lock file
      #   is created and changes can be saved. Defaults to false.
      #
      # @param lock_timeout[Integer] How many seconds to keep trying to get the
      #   read-write lock, when loading read-write.
      #
      # @return [void]
      #
      def self.load_receipts(rw = false, lock_timeout = DATASTORE_LOCK_TIMEOUT)

        # have we already loaded them?
        # (use self.reload if needed)
        return if @@installed_rcpts

        D3.log "Loading receipts, #{rw ? 'read-write' : 'read-only'}", :debug

        # get the lock if needed
        self.get_datastore_lock(lock_timeout) if rw

        @@installed_rcpts = DATASTORE.file? ? YAML.load(DATASTORE.read) : {}
        @@installed_rcpts ||= {}

        D3.log "Receipts loaded", :debug
      end # seld.load_receipts

      # Reload the existing rcpt database
      #
      # @param rw[Boolean] Load the receipts read-write, meaning that a lock file
      #   is created and changes can be saved. Defaults to false.
      #
      # @param lock_timeout[Integer] How many seconds to keep trying to get the
      #   read-write lock, when loading read-write.
      #
      # @return [void]
      #
      def self.reload_receipts (rw = false, lock_timeout = DATASTORE_LOCK_TIMEOUT)

        # if we  haven't loaded them at all yet, just do that.
        unless @@installed_rcpts
          self.load_receipts rw, lock_timeout
          return
        end # unless @@installed_rcpts

        D3.log "Reloading receipts, #{rw ? 'read-write' : 'read-only'}", :debug

        # Are we trying to re-load with rw?
        if rw
          # if we already have the lock, then we don't need to get it again
          self.get_datastore_lock(lock_timeout) unless @@got_lock
        else
          # not reloading rw, so release the lock if we have it
          self.release_datastore_lock if @@got_lock
        end

        # reload it
        @@installed_rcpts = DATASTORE.file? ? YAML.load(DATASTORE.read) : {}
        @@installed_rcpts ||= {}
        D3.log "Receipts reloaded", :debug
      end # self.reload_receipts

      # Write existing rcpt database to disk
      #
      # @return [void]
      #
      def self.save_receipts(release_lock = true)
        raise JSS::MissingDataError, "Receipts not loaded, can't save." unless @@installed_rcpts
        D3.log "Saving receipts", :debug

        unless @@got_lock
          D3.log "Receipts were loaded read-only, can't save", :error
          raise JSS::UnsupportedError,"Receipts were loaded read-only, can't save"
        end

        # ensure any deleted rcpts are gone
        @@installed_rcpts.delete_if{|title, rcpt| rcpt.deleted? }

        DATASTORE.parent.mktree unless DATASTORE.parent.directory?
        DATASTORE.jss_save YAML.dump(@@installed_rcpts)
        D3.log "Receipts saved", :debug
        if release_lock
          self.release_datastore_lock
        end
      end #self.save_receipts

      # Try to get the lock for read-write access to the datastore.
      # Raise an exception if we fail after the timeout
      #
      # @param lock_timeout[Integer] How many seconds to keep trying to get the lock?
      #
      # @return [void]
      #
      def self.get_datastore_lock (lock_timeout = DATASTORE_LOCK_TIMEOUT)
        D3.log "Attempting to get receipt datastore write lock.", :debug
        # try to get it 10x per second...
        if DATASTORE_LOCKFILE.exist?
          D3.log "Lock in use, retrying for #{lock_timeout} secs", :debug
          max_tries = lock_timeout * 10
          tries = 0
          while tries < max_tries do
            sleep 0.1
            tries += 1 if DATASTORE_LOCKFILE.exist?
          end # while
        end # if DATASTORE_LOCKFILE.exist?

        if DATASTORE_LOCKFILE.exist?
          errmsg = "Couldn't get receipt write lock after #{lock_timeout} seconds."
          lockfile_age =  (Time.now - DATASTORE_LOCKFILE.ctime).to_i

          # if its stale, warn that it might need manual fixing
          errmsg += " Potentially stale. Please investigate manually." if lockfile_age > DATASTORE_STALE_LOCK_AGE
          D3.log errmsg, :error
          raise JSS::TimeoutError, errmsg
        else
          DATASTORE_LOCKFILE.parent.mkpath
          DATASTORE_LOCKFILE.jss_save $$.to_s
          D3.log "Acquired write lock on receipt datastore.", :debug
          @@got_lock = true
        end
      end #self.get_datastore_lock

      # Release the rw lock on the datastore, if we have it.
      #
      def self.release_datastore_lock
        return nil unless @@got_lock
        DATASTORE_LOCKFILE.delete if DATASTORE_LOCKFILE.exist?
        D3.log "Receipt datastore write lock released", :debug
        @@got_lock = false
      end # self.release_datastore_lock

      # Force the release of the lock, regardless of who has it
      # Useful for testing, but very dangerous - could cause data loss.
      #
      def self.force_clear_datastore_lock
        D3.log "Force-clearing the receipt write lock", :debug
        DATASTORE_LOCKFILE.delete if DATASTORE_LOCKFILE.exist?
        @@got_lock = false
      end

      # Do we currently have the rw lock on the rcpt file?
      #
      # @return [boolean]
      #
      def self.got_lock?
        @@got_lock
      end

      # Add a D3::Client::Receipt to the local rcpt database
      #
      # @param receipt[D3::Client::Receipt] the receipt to add
      #
      # @pararm replace[Boolean] overwrite the existing receipt for this title?
      #
      # @return [void]
      #
      def self.add_receipt(receipt, replace = false)
        raise JSS::InvalidDataError, "Argument must be a D3::Client::Receipt" unless receipt.is_a? D3::Client::Receipt
        D3.log "Attempting to #{replace ? "replace" : "add"} receipt for #{receipt.patch}.", :debug
        self.reload_receipts :rw
        begin
          unless replace
            if @@installed_rcpts.member? receipt.title
              raise JSS::AlreadyExistsError, "There's already a receipt on this machine for basemame '#{receipt.title}'"
            end # if
          end # unless replace

          replacing = @@installed_rcpts[receipt.title] ? true : false
          @@installed_rcpts[receipt.title] = receipt
          self.save_receipts
          D3.log "#{replacing ? "Replaced" : "Added"} receipt for #{receipt.patch}", :info

        ensure
          # always release the rw lock even after an error
          self.release_datastore_lock
        end # begin
      end # self.add_receipt

      # Delete a D3::Client::Receipt from the local databse
      #
      # @return [void]
      #
      def self.remove_receipt(title)

        D3.log "Attempting to remove receipt for title #{title}", :info

        self.reload_receipts :rw
        begin
          old_rcpt = self.all[title]
          if old_rcpt
            @@installed_rcpts.delete title
            D3.log "Removed receipt for #{old_rcpt.patch}", :debug

            self.save_receipts
          else
            D3.log "No receipt for title #{title}", :debug
          end # if old_rcpt
        ensure
          self.release_datastore_lock
        end # begin

      end # self.remove_receipt

      # An alias of {self.remove_receipt}
      def self.delete_receipt(title) ; self.remove_receipt(title) ; end  # self.delete_receipt

      # Given a title, patch, or id return the matching D3::Receipt
      # or nil if no match.
      # If a title is used, any patch installed will
      # be returned if there is one.
      #
      # If an patch or id is used, nil will be returned unless that
      # exact pkg is installed.
      #
      # @param rcpt_to_find[String] title or patch for which to return
      #   the receipt
      #
      # @return [D3::Client::Receipt, nil] the matching receipt, if found
      #
      def self.find_receipt (rcpt_to_find)
        if self.all.keys.include? rcpt_to_find
          return self.all[rcpt_to_find]
        end
        self.all.values.each do |rcpt|
          return rcpt if rcpt.patch == rcpt_to_find or rcpt.id == rcpt_to_find.to_i
        end
        return nil
      end

      # A hash of all d3 receipts currently installed on this machine.
      # keyed by their titles. (Only one patch of a title can be installed at a time)
      #
      # @param refresh[Boolean] Should the data be re-read from disk?
      #
      # @return [Hash{String => D3::Client::Receipt}] the receipts for the currently installed pkgs.
      #
      def self.all (refresh = false)
        refresh = true if @@installed_rcpts.nil?
        self.reload_receipts if refresh
        @@installed_rcpts
      end # self.all

      # Return an array of the
      # titles of all installed d3 pkgs. This doesn't
      # include those items installed by other casper methods
      #
      def self.titles(refresh = false)
        self.all(refresh).keys
      end # self.titles

      # Return a hash of D3::Client::Receipt
      # objects for all installed pilot d3 pkgs, keyed by their titles
      #
      # @return [Hash] All pilot receipts
      #
      def self.pilots(refresh = false)
        self.all(refresh).select{|b,r| r.pilot? }
      end # installed_pkgs

      # Return a hash of D3::Client::Receipt
      # objects for all installed live d3  pkgs, keyed by their titles
      #
      # @return [Hash] All live receipts
      #
      def self.live(refresh = false)
        self.all(refresh).select {|b,r| r.live? }
      end # installed_pkgs

      # Return a hash of D3::Client::Receipt
      # objects for all installed deprecated d3 pkgs, keyed by their titles
      #
      # @return [Hash] all deprecated receipts
      #
      def self.deprecated(refresh = false)
        self.all(refresh).select {|b,r| r.deprecated? }
      end # installed_pkgs

      # Return a hash of D3::Client::Receipt
      # objects for all installed frozen d3 receipts, keyed by their titles
      #
      # @return [Hash] all frozen receipts
      #
      def self.frozen(refresh = false)
        self.all(refresh).select {|b,r| r.frozen? }
      end # installed_pkg

      # Return a hash of D3::Client::Receipt objects for all manually installed
      # pkgs (live or pilot) keyed by their titles
      #
      # @return [Hash] all manually-installed receipts
      #
      def self.manual(refresh = false)
        self.all(refresh).select {|b,r| r.manual? }
      end # installed_pkgs

      # An array of apple bundle id's for all .[m]pkgs
      # currently known to the OS's receipt db
      #
      def self.os_pkg_rcpts(refresh = false)
        @@os_pkg_rcpts = nil if refresh
        return @@os_pkg_rcpts if @@os_pkg_rcpts
        @@os_pkg_rcpts = `#{JSS::Composer::PKG_UTIL} --pkgs`.split("\n")
      end

      # Rebuild the receipt database by reading the jamf receipts
      # and using server data.
      #
      # @return [void]
      #
      def self.rebuild_database
        orig_rcpts = self.all :refresh
        new_rcpts = {}

        jamf_rcpts = JSS::Client::RECEIPTS_FOLDER.children

        D3::Package.all.values.each do |d3_pkg|

          next unless jamf_rcpts.include? d3_pkg.receipt

          # do we already have a rcpt for this patch?
          if orig_rcpts[d3_pkg.title] and (orig_rcpts[d3_pkg.title].patch == d3_pkg.patch)
            orig_rcpt = orig_rcpts[d3_pkg.title]
          else
            orig_rcpt = nil
          end

          # if there's more than one of the same title (which means
          # someone installed a d3 pkg via non-d3 means) then
          # which one wins? I say the last one, but log it.
          if new_rcpts.keys.include? d3_pkg.title
            D3.log "Rebuilding local receipt database: multiple Casper installs of title '#{d3_pkg.title}'", :warn
            new_rcpts.delete d3_pkg.title
          end # new_rcpts.keys.include? d3_pkg.title

          new_rcpts[d3_pkg.title] = D3::Client::Receipt.new(:title => d3_pkg.title,
            :version => d3_pkg.version,
            :revision => d3_pkg.revision,
            :admin => (orig_rcpt ? orig_rcpt.admin : "unknown"),
            :installed_at => (orig_rcpt ? orig_rcpt.installed_at : Time.now),
            :id => d3_pkg.id,
            :status => d3_pkg.status,
            :jamf_rcpt_file => d3_pkg.receipt,
            :apple_pkg_ids => d3_pkg.apple_receipt_data.map{|r| r[:apple_pkg_id]},
            :removable => d3_pkg.removable,
            :pre_remove_script_id => d3_pkg.pre_remove_script_id,
            :post_remove_script_id => d3_pkg.post_remove_script_id,
            :expiration => d3_pkg.expiration,
            :expiration_bundle_ids => d3_pkg.expiration_bundle_ids
          )

        end # .each do |d3_pkg|

        @@installed_rcpts = new_rcpts
        self.save_receipts

      end # rebuild db


      ############### Attributes #################

      # @return [Pathnamee] the JAMF rcpt file for this installation
      attr_reader :jamf_rcpt_file

      # @return [Time] when was it installed?
      attr_reader :installed_at

      # @return [Array<String>] if its an apple pkg, what pkg_id's does it install?
      attr_reader :apple_pkg_ids

      # @return [Boolean] was this pkg manually installed?
      attr_reader :manually_installed
      alias manual? manually_installed

      # @return [Boolean] can it be uninstalled?
      attr_accessor :removable
      alias removable? removable

      # @return [Integer,nil] the jss id of the pre-remove-script
      attr_accessor :pre_remove_script_id
      alias pre_remove_script? pre_remove_script_id

      # @return [Integer,nil] the jss id of the post-remove-script
      attr_accessor :post_remove_script_id
      alias post_remove_script? post_remove_script_id

      # @return [Boolean] is the expiration on this rcpt a custom one?
      #   If so, it'll be carried forward when auto-updates occur
      attr_accessor :custom_expiration

      # @return [Boolean] is this rcpt exempt from auto-updates to its
      #   title? If so, d3 sync will not update it, but a manual
      #   d3 install still can, and will re-enable syncs
      attr_accessor :frozen

      # @return [Time, nil] When was this app last used.
      #   nil if never checked, or no @expiration_bundle_ids
      attr_reader :last_usage

      # @return [Time, nil] When was @last_usage updated?
      #   nil if never checked, or no @expiration_bundle_ids
      attr_reader :last_usage_as_of

      ############### Constructor #################

      # Args are:
      #   - :title, required
      #   - :version, required
      #   - :revision, required
      #   - :admin, required
      #   - :id, required
      #   - :status, required, :pilot or :live (or rarely :deprecated)
      #   - :jamf_rcpt_file, required
      #
      #   - :apple_pkg_ids, optional in general, required for .pkg installers
      #   - :installed_at, optional, defaults to Time.now
      #
      #   - :removable, optional, defaults to false
      #   - :frozen, optional, defaults to false
      #   - :pre_remove_script_id, optional
      #   - :post_remove_script_id, optional
      #
      def initialize(args = {})

        missing_args = REQUIRED_INIT_ARGS - args.keys
        unless missing_args.empty?
          raise JSS::MissingDataError, "D3::Client::Receipt initialization requires these arguments: :#{REQUIRED_INIT_ARGS.join(', :')}"
        end

        args[:installed_at] ||= Time.now

        @title = args[:title]
        @version = args[:version]
        @revision = args[:revision]
        @admin = args[:admin]
        @id  = args[:id]
        @status  = args[:status]


        # if we were given a string, convert to a Pathname
        # and if it was just a filename, add the Receipts Folder path
        @jamf_rcpt_file = Pathname.new args[:jamf_rcpt_file]
        if @jamf_rcpt_file.parent != JSS::Client::RECEIPTS_FOLDER
           @jamf_rcpt_file = JSS::Client::RECEIPTS_FOLDER + @jamf_rcpt_file
        end

        @apple_pkg_ids = args[:apple_pkg_ids]
        @installed_at = args[:installed_at]

        @removable = args[:removable]
        @prohibiting_processes = args[:prohibiting_processes]
        @prohibiting_processes ||= []

        @frozen = args[:frozen]
        @pre_remove_script_id = args[:pre_remove_script_id]
        @post_remove_script_id = args[:post_remove_script_id]

        @expiration = args[:expiration].to_i
        @expiration_bundle_ids = args[:expiration_bundle_ids]
        @expiration_bundle_ids ||= []
        @custom_expiration = args[:custom_expiration]

        @manually_installed = (@admin != D3::AUTO_INSTALL_ADMIN)
        @package_type = @jamf_rcpt_file.to_s.end_with?(".dmg") ? :dmg : :pkg

      end #initialize

      ############### Public Instance Methods #################



      # UnInstall this pkg, and return the output of 'jamf uninstall' or
      # "receipts removed"
      #
      # If there's a pre-remove script, and it exits with a status of 111,
      # the d3 & jamf receipts are removed, but the actual uninstall doesn't
      # happen. This would be usefull if the uninstall process is too complex
      # for 'jamf uninstall' and is totally performed by the script.
      #
      # For receipts from .pkg installers, the force option will force deletion
      # even if the JSS isn't available. It does this by using the
      # @apple_pkg_ids with pkgutil to delete the files that were installed.
      # No pre- or post- remove scripts will be run. Use with caution.
      #
      # @param verbose[Boolean] be verbose to stdout
      #
      # @param force[Boolean] .(m)pkg receipts only!
      #   Should the uninstall happen even if the JSS isn't available?
      #   No pre- or post- scripts will be run.
      #
      # @return [void]
      #
      def uninstall (verbose = false, force = D3::forced?)

        raise D3::UninstallError,  "#{patch} is not uninstallable" unless self.removable?

        depiloting = pilot? && skipped?

        begin # ...ensure...
          if uninstall_prohibited_by_process? and (not force)
            raise D3::InstallError, "#{patch} cannot be uninstalled now because one or more of the following processes is running: #{D3::Admin::OPTIONS[:prohibiting_processes][:display_conversion].call @prohibiting_processes}"
          end
          D3::Client.set_env :removing, patch
          D3.log "Uninstalling #{patch}", :warn

          # run a preflight if needed.
          if pre_remove_script?
            (exit_status, output) = run_pre_remove verbose
            if exit_status == 111
              delete
              D3.log "pre_remove script exited 111, deleted receipt for #{patch} but not doing any more.", :info
              return true
            elsif exit_status != 0
              raise D3::UninstallError, "Error running pre_remove script (exited #{exit_status}), not uninstalling #{patch}"
            end # flight_status[0] == 111
          end # if preflight?

          # if it is still on the server...
          if JSS::Package.all_ids.include? @id
            # uninstall the pkg
            D3.log "Running 'jamf uninstall' of #{patch}", :debug
            uninstall_worked = JSS::Package.new(:id => @id).uninstall(:verbose => verbose).exitstatus == 0

          # if it isn't on the server any more....
          else
            D3.log "Package is gone from server, no index available", :info

            # if forced, deleting the rcpt is 'uninstalling'
            if force
              D3.log "Force-deleting receipt for #{patch}.", :info
              uninstall_worked = true

            # no force
            else
              # we can't do anything with dmgs
              if @package_type == :dmg
                D3.log "Package was a .dmg, can't uninstall.\n   Use --force to remove the receipt", :error
                uninstall_worked = false
              else
                uninstall_worked = uninstall_via_apple_rcpt
              end # if @package_type == :dmg
            end # if force

          end # JSS::Package.all_ids.include? @id

          ## Uninstall worked, so do more things and stuffs
          if uninstall_worked

            # remove this rcpt
            delete
            D3.log "Done, uninstalled #{patch}", :warn
            # run a postflight if needed
            if post_remove_script?
              (exit_status, output) = run_post_remove verbose
              if exit_status != 0
                raise D3::UninstallError,  "Error running post_remove script (exited #{exit_status}) for #{patch}"
              end
            end # if post_install_script?

          # uninstall failed, but force deletes rececipt
          else
            if force
              D3.log "Uninstall failed, but force-deleting receipt for #{patch}.", :warn
              delete
            else
              raise D3::UninstallError, "There was a problem uninstalling #{patch}"
            end # if force
          end #if uninstall_worked

          # do any sync-type auto installs if we just removed a pilot
          # then the machine will get any live patch if it should.
          D3::Client.do_auto_installs(OpenStruct.new) if depiloting

        ensure
          D3::Client.unset_env :removing
        end # begin...ensure


      end #uninstall

      # Run the pre-remove script, return the exit status and output
      #
      # @param verbose[Boolean] run verbosely?
      #
      # @return [Array<Integer, String>] the exit status and output of the script
      #
      def run_pre_remove (verbose = false)
        D3::Client.set_env :pre_remove, patch
        D3.log "Running pre_remove script", :debug
        begin
          result = JSS::Script.new(:id => @pre_remove_script_id).run :verbose => verbose, :show_output => verbose
        rescue D3::ScriptError
          raise PreRemoveError, $!
        ensure
          D3::Client.unset_env :pre_remove
        end
        D3.log "Finished pre_remove script", :debug
        return result
      end

      # Run the post-remove script, return the exit status and output
      #
      # @param verbose[Boolean] run verbosely?
      #
      # @return [Array<Integer, String>] the exit status and output of the script
      #
      def run_post_remove (verbose = false)
        D3::Client.set_env :post_remove, patch
        D3.log "Running post_remove script", :debug
        begin
          result = JSS::Script.new(:id => @post_remove_script_id).run :verbose => verbose, :show_output => verbose
        rescue D3::ScriptError
          raise PostRemoveError, $!
        ensure
          D3::Client.unset_env :post_remove
        end
        D3.log "Finished post_remove script", :debug
        return result
      end

      # Uninstall this .pkg by looking up the files it installed via
      # pkgutil and deleting them directly. Doesn't talk to the JSS
      # and only works for .pkg installers (.dmg installers don't
      # write their file lists to the local package db.)
      # This means that it won't run pre/post remove scripts either!
      #
      # @param verbose[Boolean] Should each deleted file be meentioned
      #
      # @return [Boolean] Was the uninstall successful?
      #
      def uninstall_via_apple_rcpt (verbose = false)

        D3.log "Uninstalling #{patch} via Apple pkg receipts", :debug
        raise D3::UninstallError,  "#{patch} is not a .pkg installer. Can't use Apple receipts." if @package_type == :dmg
        to_delete = {}
        begin
          installed_apple_rcpts = `#{JSS::Composer::PKG_UTIL} --pkgs`.split("\n")
          @apple_pkg_ids.each do |pkgid|
            unless installed_apple_rcpts.include? pkgid
              D3.log "No local Apple receipt for '#{pkgid}', ignoring", :warn
              next
            end

            # this gets them in reverse order, so we can
            # delete files and then test for and delete empty dirs on the way
            to_delete[pkgid] = `#{JSS::Composer::PKG_UTIL} --files '#{pkgid}' 2>/dev/null`.split("\n").reverse
            raise D3::UninstallError, "Error querying pkg file list for '#{pkgid}'" if $CHILD_STATUS.exitstatus > 0
          end # each pkgid

          to_delete.each do |pkgid, paths|
            D3.log "Deleting items installed by apple pkg-id #{pkgid}", :debug
            paths.each do |path|
              target = Pathname.new "/#{path}"
              target.delete if target.file?
              target.rmdir if target.directory? and target.children.empty?
              D3.log "Deleted #{path}", :debug
            end # each path
            system "#{JSS::Composer::PKG_UTIL} --forget '#{pkgid}' &>/dev/null"
          end # each |pkgid, paths|
        rescue
          D3.log $!, :warn
          D3.log_backtrace
          return false
        end # begin
        return true
      end # uninstall_via_apple_rcpt

      # Repair any missing or invalid data
      # in the receipt based on the matching D3::Package data
      #
      # @return [void]
      #
      def repair
        raise JSS::UnsupportedError, "This receipt has been deleted" if @deleted

        d3_pkg = D3::Package.new :id => @id

        @title = d3_pkg.title
        @version = d3_pkg.version
        @revision = d3_pkg.revision
        @admin ||= "Repaired"
        @status  = d3_pkg.status
        @jamf_rcpt_file = d3_pkg.receipt
        @apple_pkg_ids = d3_pkg.apple_receipt_data.map{|r| r[:apple_pkg_id]}
        @removable = d3_pkg.removable
        @manually_installed = (@admin != D3::AUTO_INSTALL_ADMIN)
        @package_type = @jamf_rcpt_file.end_with?(".dmg") ? :dmg : :pkg
        @expiration = d3_pkg.expiration
        @expiration_bundle_ids = d3_pkg.expiration_bundle_ids

      end # repair rcpt

      # Is this rcpt frozen?
      #
      # @return [Boolean]
      #
      def frozen?
        return true if @frozen
        return false
      end

      # Freeze this rcpt
      #
      # @return [void]
      #
      def freeze
        @frozen = true
      end

      # Unfreeze this rcpt
      #
      # @return [void]
      #
      def unfreeze
        @frozen = false
      end
      alias thaw unfreeze

      # Set a new expiration period
      # WARNING: setting this to a lower value
      # might cause the rcpt to be uninstalled
      # at the next sync.
      #
      # @param new_val[Integer] The new expiration period in days
      #
      # @return [void]
      #
      def expiration= (new_val)
        raise JSS::InvalidDataError, "#{patch} is not removable, no expiration allowed." unless @removable or new_val.to_i == 0
        @expiration = new_val.to_i
      end

      # Set a new expiration path
      # WARNING: changing this to a new value
      # might cause the rcpt to be uninstalled
      # at the next sync.
      #
      # @param new_val[Pathname,String] The new expiration path
      #
      # @return [void]
      #
      def expiration_bundle_ids= (new_val)
        @expiration_bundle_ids = new_val
      end

      # Set new prohibiting process(es)
      def prohibiting_processes=(new_val)
        @prohibiting_processes = new_val
      end

      # Update the current receipt in the receipt store
      def update
        D3::Client::Receipt.add_receipt(self, :replace)
      end

      # Delete this receipt from the local machine.
      # This removes both the JAMF receipt file, and
      # the D3::Client::Receipt from the datastore, and sets @deleted
      # to true.
      #
      # @return [void]
      #
      def delete
        @jamf_rcpt_file.delete if @jamf_rcpt_file.exist?
        D3::Client::Receipt.remove_receipt @title
        D3.log "Deleted JAMF receipt file #{@jamf_rcpt_file.title}", :debug
        @deleted = true
      end

      # @return [Boolean] has this rcpt been deleted?
      #   See also {#delete}
      #
      def deleted?
        @deleted
      end

      # @return [String] a human-readable string of details about this
      # installed pkg
      #
      def formatted_details
        deets = <<-END_DEETS
patch: #{@patch}
Status: #{@status}
Frozen: #{frozen? ? "yes" : "no"}
Install date: #{@installed_at.strftime "%Y-%m-%d %H:%M:%S"}
Installed by: #{@admin}
Manually installed: #{manual?}
JAMF receipt file: #{@jamf_rcpt_file.title}
Casper Pkg ID: #{@id}
Un-installable: #{removable? ? "yes" : "no"}
        END_DEETS

        if removable?
          if JSS::API.connected?
            pre_name = pre_remove_script_id ? JSS::Script.map_all_ids_to(:name)[pre_remove_script_id] : "none"
            post_name = post_remove_script_id ? JSS::Script.map_all_ids_to(:name)[post_remove_script_id] : "none"
          else # not connected
            pre_name = pre_remove_script_id ? "yes" : "none"
            post_name = post_remove_script_id ? "yes" : "none"
          end
          deets += <<-END_DEETS
Pre-remove script: #{pre_name}
Post-remove script: #{post_name}
          END_DEETS
        end # if removable?

        if @package_type == :pkg and @apple_pkg_ids
          deets += <<-END_DEETS
Apple.pkg ids: #{@apple_pkg_ids.join(', ')}
          END_DEETS
        end
        if @expiration_bundle_ids
          if @expiration.to_i > 0
            lu = last_usage
            if lu.nil?
              last_usage_display = "Unknonwn"
            elsif lu == @installed_at
              last_usage_display = "Not since installation (#{days_since_last_usage} days ago)"
            else
              last_usage_display = "#{lu.strftime '%Y-%m-%d %H:%M:%S'} (#{days_since_last_usage} days ago)"
            end #  if my_last_usage == @installed_at

            deets += <<-END_DEETS
Expiration period: #{@expiration} days#{@custom_expiration ? ' (custom)' : ''}
Expiration path(s): #{D3::Database::ARRAY_OF_PATHNAMES_TO_COMMA_STRING.call @expiration_bundle_ids}
Last brought to foreground: #{last_usage_display}
            END_DEETS
          end # if exp > 0
        end # if exp path
        return deets
      end

      # If a currently installed pilot goes live, just change it's state and mark it so.
      #
      def make_live
        return true if live?
        D3.log "Marking pilot receipt #{patch} live", :debug
        @status = :live
        update
      end

      # Should this item be expired right now?
      #
      # @return [Boolean]
      #
      def should_expire?

        # gotta be expirable
        return false if @expiration.nil? or @expiration == 0

        # gotta have an expiration path
        if @expiration_bundle_ids.empty?
          D3.log "Not expiring #{patch} because: No Expiration Path(s) for #{patch}", :debug
          return false
        end

        # must have up-to-date last usage data
        # this also checks for usage dir existence and plist age
        my_last_usage = last_usage
        unlaunched_days = days_since_last_usage

        # gotta have expirations turned on system-wide
        unless D3::CONFIG.client_expiration_allowed
          D3.log "Not expiring #{patch} because: expirations not allowed on this client", :debug
          return false
        end

        # gotta be removable
        unless @removable
          D3.log "Not expiring #{patch} because: not removable", :debug
          return false
        end

        # gotta have an expiration set for this rcpt.
        if (not @expiration.is_a? Fixnum) or @expiration <= 0
          D3.log "Not expiring #{patch} because: expiration value is invalid", :debug
          return false
        end

        # the app usage monitor must be running
        all_procs = `/bin/ps -A -c -o user -o comm`.split("\n")
        if all_procs.select{|p| p =~ /\s#{APP_USAGE_MONITOR_PROC}$/}.empty?
          D3.log "Not expiring #{patch} because: '#{APP_USAGE_MONITOR_PROC}' isn't running", :debug
          return false
        end

        # did we get any usage dates above?
        unless my_last_usage and unlaunched_days
          D3.log "Not expiring #{patch} because: could not retrieve last usage data", :debug
          return false
        end

        # must be unlaunched for at least the expiration period
        if unlaunched_days <= @expiration
          D3.log "Not expiring #{patch} because: path has launched within #{expiration} days", :debug
          return false
        end

        # gotta be connected to d3
        unless D3.connected?
          D3.log "Not expiring #{patch} because: not connected to the servers", :debug
          return false
        end

        # if we're here, expire this thing
        return true
      end # should expire

      # Expire this item - uninstall it if no foreground use in
      # the expiration period
      #
      # @return [String, nil] the patch that was expired or nil if none
      #
      def expire(verbose = false, force = D3.forced?)
        return nil unless should_expire?
        begin
          D3::Client.set_env :expiring, patch
          D3.log "Expiring #{patch} after #{expiration} days of no use.", :warn
          uninstall verbose, force
          D3.log "Done expiring #{patch}", :info
        rescue
          D3.log "There was an error expiring #{patch}:\n   #{$!}", :error
          D3.log_backtrace
        ensure
          D3::Client.unset_env :expiring
        end
        return deleted? ? patch : nil
      end # expire

      # Return the number of days since the last usage for the @expiration_bundle_ids
      # for this receipt
      ###s
      # Returns nil if last_usage is nil
      #
      # See also {#last_usage}
      #
      # @return [Integer, nil] days since last usage
      #
      def days_since_last_usage
        lu = last_usage
        return nil unless lu
        ((Time.now - lu) / 60 / 60 / 24).to_i
      end

      # The last usage date for this receipt and the number of days ago that was
      #
      # If we have access to the usage plists maintained by d3RepoMan, then read
      # them and find the last usage, store it in @last_usage , and return it
      #
      # If we don't have access, return @last_usage, which is updated during
      # d3 sync.
      # Its up to the caller to use @last_usage_as_of appropriately.
      #
      # If @last_usage has never been set, or there is no expiration path,
      # returns nil.
      #
      # @return [Time,nil] The last usage date, or nil if no
      #    expiration path or the data wasn't retrievable.
      #
      def last_usage
        return nil unless @expiration_bundle_ids

        now = Time.now

        # if it's in the foreground right now, return [now, 0]
        fgnd_path = D3::Client.foreground_executable_path
        if fgnd_path
          now_in_foreground = @expiration_bundle_ids.select{|p| fgnd_path == p}.length > 0
        else
          now_in_foreground = nil
        end

        if now_in_foreground
          @last_usage = now
          @last_usage_as_of = now
          return @last_usage
        end

        # if we're root, read the usage plists
        if JSS.superuser?

          # usage data dir must exist
          unless LAST_APP_USAGE_DIR.directory?
            D3.log "Last app usage dir '#{LAST_APP_USAGE_DIR}' doesn't exist or isn't a directory.", :debug
            return nil
          end

          # all the plists in the usage dir
          plists = LAST_APP_USAGE_DIR.children.select{|c| c.extname == ".plist" }

          # gotta have new-enough usage data
          newest_mtime = plists.map{|pl| pl.stat.mtime}.max
          app_usage_update_age =  (now - newest_mtime).to_i
          if app_usage_update_age > MAX_APP_USAGE_UPDATE_AGE
            D3.log "Last app usage update more than #{MAX_APP_USAGE_UPDATE_AGE} seconds ago.", :debug
            return nil
          end

         # loop through the plists, get the newest usage time for any
          # expiration paths, and append it to all_usages
          all_usages = []
          plists.each do |plist|
            usage_times = D3.parse_plist plist
            my_usage_keys = usage_times.keys.map{|p| Pathname.new(p)}
            exp_paths_with_usage = @expiration_bundle_ids & my_usage_keys
            exp_paths_with_usage.each{|p| all_usages <<  usage_times[p.to_s].to_time }
          end # do plist

          @last_usage = all_usages.compact.max

          # if never been used, last usage is the install date
          @last_usage ||= @installed_at

          # prohibiting_processes should always be an array
          @prohibiting_processes ||= []

          # if the install time is newer than the last usage,
          # use the install time.
          # this basically "resets the timer" when
          # something is re-installed.
          @last_usage = @installed_at if @installed_at > @last_usage

          @last_usage_as_of = now

          update

        end # if JSS.superuser?
        return @last_usage

      end # last_usage

      # set the status - for rcpts, this can't be a private method
      #
      # @param new_status[Symbol]  one of the  valid STATUSES
      #
      # @return [Symbol] the new status
      #
      def status= (new_status)
        raise JSS::InvalidDataError, "status must be one of :#{D3::title::STATUSES.join(', :')}" unless D3::title::STATUSES.include? new_status
        @status = new_status
        update
      end


      ############### Private Instance Methods #################

      private

      # Is there a process running that would prevent removal?
      #
      # @return [Boolean]
      #
      def uninstall_prohibited_by_process?
        D3.prohibited_by_process_running? @prohibiting_processes
      end #

    end # class Receipt
  end # class Client
end # module
