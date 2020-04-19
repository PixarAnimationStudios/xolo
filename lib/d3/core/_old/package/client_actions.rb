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
  class Package < JSS::Package

    # Run the make_live script, if any. We do this by creating and runngin
    # a tmp file, rather than using the jamf binary, because this wont'
    # be done as root, so the jamf binary can't be run.
    #
    # @return [Process::Status] the status of the finished script.
    #
    def run_make_live_script
      # Run the make_live script if any
      if script = D3::CONFIG.admin_make_live_script
        if JSS::Script.all_names.include? script
          code = JSS::Script.new(name: script).code
        elsif JSS::Script.all_ids.include? script
          code = JSS::Script.new(id: script).code
        else
          return nil
        end

        return nil unless code
        return nil unless code.start_with? "#!"

        tmp_file =  Pathname.new Tempfile.new("mklive")
        tmp_file.jss_touch
        tmp_file.chmod 0700
        tmp_file.jss_save code

        ENV['D3_MAKE_LIVE_patch'] = patch
        ENV['D3_MAKE_LIVE_ADMIN'] = @admin
        ENV['D3_MAKE_LIVE_DESC'] = description
        ENV['D3_MAKE_LIVE_AUTO_GROUPS'] = auto_groups.join(',')
        ENV['D3_MAKE_LIVE_EXCL_GROUPS'] = excluded_groups.join(',')

        system tmp_file.to_s
        tmp_file.delete

        ENV['D3_MAKE_LIVE_patch'] = nil
        ENV['D3_MAKE_LIVE_ADMIN'] = nil
        ENV['D3_MAKE_LIVE_DESC'] = nil
        ENV['D3_MAKE_LIVE_AUTO_GROUPS'] = nil
        ENV['D3_MAKE_LIVE_EXCL_GROUPS'] = nil
      end
    end

    # Install this pkg on this machine. D3 pkgs are more involved than plain JSS pkgs.
    #
    # @param args[Hash] The options for installation, see also the options to JSS::Package#install, which are accepted here.
    #
    # @options args :admin [String] the name of the person doing the install
    #
    # @options args :force [Boolean] should the installtion be forced to act unnaturally?
    #
    # @options args :puppywalk [Boolean]  if true, we're installing logout-installs immediately, not queueing them
    #
    # @options args :expiration [Integer]  Override any server-defined expiration period, value is days unlaunched.
    #   Zero = don't expire. The pkg must be removable to be expired.
    #
    # @options args :verbose [Boolean] Be loud to stdout, defaults to false
    #
    # @return [String] the output of the jamf install command
    #
    def install(args = {})

      # force can't get around these:
      raise D3::InstallError, "This package is missing from the JSS, cannot install." if @status == :missing
      check_oses
      check_cpu

      begin  # for the ensure below

        # if this item is now being installed by puppies at logout,
        # the PuppyQ has our admin name, force setting, and expiration.
        # It if isn't in the puppyQ, then those values should
        # have come from the args
        if args[:puppywalk] and D3::PUPPY_Q.q[@title] then
          args[:admin] = D3::PUPPY_Q.q[@title].admin ? D3::PUPPY_Q.q[@title].admin : "puppy-install"
          args[:force] = D3::PUPPY_Q.q[@title].force
          args[:expiration] = D3::PUPPY_Q.q[@title].expiration
        else
          # if this is a manual install, we should know
          # who's doing it
          args[:admin] ||= D3.admin
        end

        forced = args[:force] or D3::forced?

        # excluded pkgs
        check_for_exclusions  unless forced

        @admin = args[:admin]

        # pilot?
        D3::Client.set_env :installing, patch
        D3::Client.set_env :pkg_status, @status

        # force?
        @using_force = forced ? " with force" : ""

        # pilot installs need an admin from the args or the queue
        raise JSS::MissingDataError, "Missing :admin for pilot install." if pilot? and @admin == D3::AUTO_INSTALL_ADMIN

        # If we aren't actually installing the puppy queue items
        # and there's already a member of this title in the queue
        # raise an exception,
        if D3::PUPPY_Q.pups.include? @title && (not args[:puppywalk]) && (not forced)
            raise D3::InstallError, "#{@title} (#{D3::PUPPY_Q.q[@title].patch}) is already queued for puppies. Use force if needed."
        end

        if removable?
          if args[:expiration] && @expiration != args[:expiration]
            @expiration_to_apply = args[:expiration]
            @custom_expiration = args[:expiration]
          else
            @expiration_to_apply = @expiration
            @custom_expiration = false
          end
        else
          # not removable, can't expire
          @expiration_to_apply = 0
        end # if remmovable

        #
        # Queue for Puppies
        #
        if reboot? && (not args[:puppywalk])
          queue_for_puppies forced

        #
        # Regular Install...
        #
        else

          unless forced
            raise D3::InstallError, "#{patch} cannot be installed now because one or more of the following processes is running: #{D3::Admin::OPTIONS[:prohibiting_processes][:display_conversion].call @prohibiting_processes}."  if install_prohibited_by_process?
          end # unless forced

          remove_previous_installs_if_needed (args[:verbose])

          D3.log "Installing: #{patch} (#{@status})#{@using_force}", :warn

          # pre-install script
          pre_install_status = run_pre_install_script(args[:verbose])

          # exit 111 means write receipts, but don't acutally install
          if pre_install_status == 111 then
            D3.log "Pre-install script for #{patch} exited with status '111'; Not installing but writing receipt.", :info
            write_rcpt
            # if this was a puppy install, remove it from the queue
            D3::PUPPY_Q - @title
            return pre_install_status
          elsif pre_install_status != 0  then
             D3.log  "Pre_install script for #{patch} failed, exit status: #{pre_install_status}, not installing.", :error
            raise D3::PreInstallError,  "Pre_install script for #{patch} failed, exit status: #{pre_install_status}, not installing."
          end # pre_install_status == 111

          # if forced, make the os forget this has been installed before
          if forced and @apple_receipt_data.is_a? Array
            @apple_receipt_data.each do |r|
              D3.log "Forcing OS to forget installer receipt for: #{r[:apple_pkg_id]}", :info
              system "#{JSS::Composer::PKG_UTIL} --forget '#{r[:apple_pkg_id]}' &>/dev/null"
            end # each do r
          end # if force

          # get the read-only passwd for the dist point, if needed
          args[:ro_pw] =  D3::Client.get_ro_pass :dist

          # Install It Already!
          D3.log "Running 'jamf install' of #{patch}", :info

          if install_result = super(args)  # install was good...
            D3.log "Finished 'jamf install' of #{patch}", :debug

            # write our receipt
            write_rcpt

            # if this was a puppy install, remove it from the queue
            D3::PUPPY_Q - @title

            # run a postflight if needed
            post_install_status = run_post_install_script(args[:verbose])
            if  post_install_status != 0
              D3.log "Post_install script for #{patch} failed, exit status: #{post_install_status}", :error
              raise D3::PostInstallError, "Post_install script for #{patch} failed, exit status: #{post_install_status}"
            end
            D3.log "Done installing #{patch}#{@using_force}", :warn

          else #  bad install
            raise D3::InstallError, "There was a problem installing #{patch}, 'jamf install' failed"
          end # if super args

          return install_result
        end # if reboot?

      ensure
        D3::Client.unset_env :installing
        D3::Client.unset_env :pkg_status
      end # begin...ensure
    end #install

    # This just queues this installer for installation at the next puppywalk
    # For now, we're intentionally NOT caching the installer for off-line installation.
    # The puppy installer will only run when the machine can talk to the JSS
    #
    def queue_for_puppies (force = D3::forced?)

        # create the puppy
        new_pup = D3::PuppyTime::PendingPuppy.new( :title => @title,
          :version => @version,
          :revision => @revision,
          :admin => @admin,
          :force => force,
          :custom_expiration => @custom_expiration,
          :status => @status )

        # add it to the queue - this will return true or false
        added_2_q = D3::PUPPY_Q + new_pup

        # tell someone
        D3.log "Added #{patch} (#{@status}) to the puppy queue#{@using_force}", :warn if added_2_q

        return true
    end

    # Run the pre-install script, if any.
    #
    # @param verbose[Boolean] Should the script be run verbosely?
    #
    # @return [Integer, nil] The exitstatus of the script, 0 if no script
    #
    def run_pre_install_script(verbose = false)
      return 0 unless pre_install_script?
      begin
        D3::Client.set_env :pre_install, patch
        D3.log "Running pre_install script for #{patch}", :info
        (exit_status, output) = JSS::Script.new(:id => @pre_install_script_id).run :verbose => verbose, :show_output => verbose
        D3.log "Finished pre_install script for #{patch}", :debug
      rescue D3::ScriptError
        raise PreInstallError, $!
      ensure
        D3::Client.unset_env :pre_install
      end # begin
      return exit_status
    end # run pre install

    # Run the post-install script, if any.
    #
    # @param verbose[Boolean] Should the script be run verbosely?
    #
    # @return [Integer, nil] The exitstatus of the script, 0 if no script
    #
    def run_post_install_script(verbose = false)
      return 0 unless post_install_script?
      begin
        D3::Client.set_env :post_install, patch
        D3.log "Running post_install script for #{patch}", :info
        (exit_status, output) = JSS::Script.new(:id => @post_install_script_id).run :verbose => verbose, :show_output => verbose
        D3.log "Finished post_install script for #{patch}", :debug
      rescue D3::ScriptError
        raise PostInstallError, $!
      ensure
        D3::Client.unset_env :post_install
      end # begin
      return exit_status
    end # run post install

  end # class Package
end # module D3
