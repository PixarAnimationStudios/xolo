# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

# frozen_string_literal: true

module Xolo

  module Server

    module Helpers

      # Nightly maintenance tasks
      # - accept lingering TEd EAs, if configured to
      # - autorelease versions
      # - clean up old versions
      # - notify title maintainers of old unreleased pilots
      #
      # Also, alerts will be posted, and Emails will be sent to the
      # admins who added versions that have been in pilot for more than
      # some period of time.
      #
      #
      module Maintenance

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # Constants
        #####################################

        # TODO: ? use the next 3 values as defaults, and
        # set them in the server config

        # how often does our maint timer check to see if it should run maintenance?
        # Slightly less than an hour means there will always be at least one check every
        # hour, sometimes two.
        MAINT_CHECK_INTERVAL = 3500
        # MAINT_CHECK_INTERVAL = 600

        # At what hour should the nightly maintenance run?
        MAINT_HOUR = 2
        # MAINT_HOUR = 10

        # Maint won't run unless the last run was at least this many
        # seconds ago.
        # 23 hrs ago means that even if we check twice within the
        # MAINT_HOUR, only the first one will run.
        MAINT_MAX_FREQ_SECS = 23 * 3600

        # the route we POST to, to start the nightly process.
        TIMED_MAINT_TRIGGER_ROUTE = '/maint/maint-internal'

        # on which day of the month should we send the unreleased pilot notifications?
        UNRELEASED_PILOTS_NOTIFICATION_DAY = 1

        # Once a version becomes deprecated, it will
        # be automatically deleted this many days later.
        # If not set in the server config, this is
        # the default value.
        # use 0 or less to disable maintenance of deprecated versions
        DFT_DEPRECATED_LIFETIME_DAYS = 30

        # If a pilot has not been released in this many
        # days, notify someone about it weekly, asking
        # to release it or delete it.
        # If not set in the server config, this is the
        # default value.
        DFT_UNRELEASED_PILOTS_NOTIFICATION_DAYS = 180

        # when doing a full shutdown, we need to unload the launchd plist
        SERVER_LAUNCHD_PLIST = Pathname.new '/Library/LaunchDaemons/com.pixar.xoloserver.plist'

        # Module Methods
        #####################################

        # A mutex for the maint process
        #
        # @return [Mutex] the mutex
        #####################
        def self.maint_mutex
          @maint_mutex ||= Mutex.new
        end

        # nightly maint is done by a Concurrent::TimerTask, which checks every
        # hour to see if it should do anything.
        #
        # It will only do the maint if the current time is in the MAINT_HOUR hour
        # (02:00 - 02:59 if MAINT_HOUR = 2)
        #
        # We trigger the maint by POSTing to TIMED_MAINT_TRIGGER_ROUTE, so that it runs
        # in the context of a request, having access to Title and Version instantiation.
        #
        # @return [Concurrent::TimerTask] the timed task to do log rotation
        ######################################
        def self.maint_timer_task
          return @maint_timer_task if @maint_timer_task

          @maint_timer_task =
            Concurrent::TimerTask.new(execution_interval: MAINT_CHECK_INTERVAL) { post_to_start_maint }

          Xolo::Server.logger.info "Created Concurrent::TimerTask for nightly maintenance. Will check every #{MAINT_CHECK_INTERVAL} secs, and run during the hour of: #{MAINT_HOUR}"

          @maint_timer_task
        end

        # When was our last maint?
        # @return [Time] the time of the last maint, or the epoch if never
        ######################################
        def self.last_maint
          @last_maint ||= Time.at(0)
        end

        # Set the time of the last maint
        # @param time [Time] the time of the last maint
        # @return [Time] the time of the last maint
        ######################################
        def self.last_maint=(time)
          @last_maint = time
        end

        # @return [Time] Is maintenance running right now? true if the mutex is locked
        ######################################
        def self.maint_running?
          maint_mutex.locked?
        end

        # post to the server to start the maint process
        # This is done so that the maint can run in the context of a request,
        # having access to Title and Version instantiation.
        #
        # @param force [Boolean] force the maint to run now
        # @return [void]
        ######################################
        def self.post_to_start_maint(force: false)
          if Xolo::Server.shutting_down?
            Xolo::Server.logger.info 'Not starting maintenance, server is shutting down'
            return
          end

          # only run the maintenance if it's during the MAINT_HOUR
          # and the last one was more than MAINT_MAX_FREQ_SECS ago
          if force
            Xolo::Server.logger.info 'Maint: Starting now due to force'

          elsif Time.now.hour == MAINT_HOUR && (Time.now - last_maint) > MAINT_MAX_FREQ_SECS
            Xolo::Server.logger.info 'Maint: Starting nightly run now'

          else
            Xolo::Server.logger.info "Maint: Not starting, it isn't time"
            return
          end

          uri = URI.parse "https://#{Xolo::Server::Helpers::Auth::IPV4_LOOPBACK}#{TIMED_MAINT_TRIGGER_ROUTE}"
          https = Net::HTTP.new(uri.host, uri.port)
          https.use_ssl = true
          # The server cert may be self-signed and/or doesn't
          # match the hostname, so we need to disable verification
          https.verify_mode = OpenSSL::SSL::VERIFY_NONE

          request = Net::HTTP::Post.new(uri.path)
          request['Authorization'] = Xolo::Server::Helpers::Auth.internal_auth_token_header

          response = https.request(request)
          Xolo::Server.logger.info "Maintenance request response: #{response.code} #{response.body}"
        end

        # Perform maintenance tasks
        # @return [void]
        ################################
        def run_maint
          if Xolo::Server.shutting_down?
            log_info 'Maint: Not starting maint, server is shutting down'
            return
          end

          mutex = Xolo::Server::Helpers::Maintenance.maint_mutex

          if mutex.locked?
            log_warn 'Maint: already running, skipping this run'
            return
          end
          mutex.lock

          log_info 'Maint: starting'

          # instantiate all the titles once now, rather than in all the task methods
          title_objects_for_maint = all_title_objects refresh: true

          # add new maintenance tasks/methods here
          ######
          accept_title_editor_eas title_objects_for_maint
          auto_release_versions title_objects_for_maint
          cleanup_versions title_objects_for_maint
          notify_admins_of_unreleased_pilots title_objects_for_maint

          # make note of the time.
          Xolo::Server::Helpers::Maintenance.last_maint = Time.now
          log_info 'Maint: complete'

          log_debug 'Maint: running update_client_data after all tasks'
          update_client_data post_maint: true
        ensure
          mutex&.unlock
        end

        # look for any titles that need their Title Editor EA's accepted,
        # and auto accept them if we need to
        # @return [void]
        ######################################
        def accept_title_editor_eas(title_objects)
          unless Xolo::Server.config.jamf_auto_accept_xolo_eas
            log_debug 'Maint: The xolo server is not configured to auto-accept Title Editor EAs'
            return
          end

          log_info 'Maint: Looking for Title Editor EAs to auto-accept'

          title_objects.each do |title_obj|
            title = title_obj.title
            next if title_obj.subscribed?
            next unless title_obj.jamf_patch_ea_awaiting_acceptance?

            log_info "Maint: Auto-accepting Title Editor EA for title '#{title}'"
            title_obj.accept_jamf_patch_ea_via_api
          rescue => e
            log_error "Maint: Error auto-accepting Title Editor EA for title '#{title}': #{e}"
          end # Xolo::Server::Title.all_titles.each

          log_info 'Maint: Done with Title Editor EAs to auto-accept'
        end

        # Do any pending auto-releases
        # @return [void]
        ##############################
        def auto_release_versions(title_objects)
          log_info 'Maint: Auto-releasing appropriate versions'

          today = Date.today

          # Loop thru the titles
          title_objects.each do |title_obj|
            title = title_obj.title

            # nothing to do if its nil or 'none'
            next if title_obj.auto_release_delay.nil? || title_obj.auto_release_delay == Xolo::NONE

            # title must be subscribed and autopkg
            # (enforced in xadm)
            next unless title_obj.subscribed? && !title_obj.autopkg_recipe.pix_empty?

            # title must have a non-negative integer for auto_release_delay,
            # (number of days to wait before release)
            # could be zero. (enforced in xadm)
            # NOTE: it is stored as a string because it might be 'none'
            # TODO: store none as nil, so we don't have to do the pix_integer check??
            delay = title_obj.auto_release_delay.to_i
            next unless title_obj.auto_release_delay&.pix_integer? && !delay.negative?

            # Any version with this creation date should be released now, skip if not
            # So if the auto_release_delay is 7, its today - 7 days.
            # if the auto_release_delay is 0, its today - 0 days, aka today
            creation_date_to_be_released_today = today - delay

            # Find the newest pilot version whose creation date is
            # creation_date_to_be_released_today or earlier
            # That one should be released now.
            vobj_to_release = nil

            # version objects are in order of newest to oldest
            title_obj.version_objects.each do |vobj|
              next unless vobj.pilot?
              next unless vobj.creation_date.to_date <= creation_date_to_be_released_today

              vobj_to_release = vobj
              break
            end

            # no versions to release today
            next unless vobj_to_release

            # release it
            log_debug "Maint: About to auto-release version '#{vobj_to_release.version}' of '#{title}' which came out #{vobj_to_release.creation_date}"

            # releasing a version is done via the title obj, since it affects the status
            # of all versions.
            title_obj.release vobj_to_release.version

            log_info "Maint: Auto-released version '#{vobj_to_release.version}' of '#{title}' which came out #{vobj_to_release.creation_date}", alert: true

            # pause for server to catch up
            sleep 60
          end # each title

          log_debug 'Maint: Done auto-releasing'
        end

        # Cleanup versions.
        # @return [void]
        ################################
        def cleanup_versions(title_objects)
          log_info 'Maint: Cleaning up deprecated and skipped versions'

          # Loop thru the titles
          title_objects.each do |title_obj|
            title_obj.version_objects.each do |version|
              if version.deprecated?
                cleanup_deprecated_version version
              elsif version.skipped?
                cleanup_skipped_version version
              end # case
            end # each version
          end # each title
          log_info 'Maint: Version cleanup complete'
        end

        # Cleanup a deprecated version.
        # @param version [Xolo::Server::Version] the version to cleanup
        # @return [void]
        ################################
        def cleanup_deprecated_version(version)
          # do nothing if the deprecated_lifetime_days is 0 or less
          return unless deprecated_lifetime_days.positive?

          # how many days has this version been deprecated?
          days_deprecated = (Time.now - version.deprecation_date) / 86_400
          return unless days_deprecated > deprecated_lifetime_days

          log_info "Maint: Deleting deprecated version '#{version.version}' of title '#{version.title}'"
          version.delete
        end

        # Cleanup a skipped version.
        # @param version [Xolo::Server::Version] the version to cleanup
        # @return [void]
        ################################
        def cleanup_skipped_version(version)
          return if Xolo::Server.config.keep_skipped_versions

          log_info "Maint: Deleting skipped version '#{version.version}' of title '#{version.title}'"
          version.delete
        end

        # Notify the admins about unreleased pilots if needed
        # @return [void]
        ################################
        def notify_admins_of_unreleased_pilots(title_objects)
          unless Time.now.day == UNRELEASED_PILOTS_NOTIFICATION_DAY
            log_debug 'Maint: Not notifying admins of old pilots, wrong day of the month.'
            return
          end
          unless unreleased_pilots_notification_days&.positive?
            log_debug 'Maint: Not notifying admins of old pilots, unreleased_pilots_notification_days is not a positive integer'
            return
          end

          log_info 'Maint: Notifying admins about old unreleased pilots'

          title_objects.each do |title_obj|
            next unless title_obj.latest_version

            latest_vers_obj = instantiate_version title: title_obj, version: title_obj.latest_version
            next unless latest_vers_obj.pilot?

            days_in_pilot = ((Time.now - latest_vers_obj.creation_date) / 86_400).to_i

            next unless days_in_pilot > unreleased_pilots_notification_days

            alert_msg = "Maint: Notifying #{title_obj.contact_email} about unreleased pilot '#{latest_vers}' of title '#{title_obj.title}', in pilot for #{days_in_pilot} days"

            log_info alert_msg
            send_alert alert_msg

            email_msg = <<~MSG
            The newest version '#{latest_vers_obj.version}' of title '#{title_obj.title}' has been in pilot for #{days_in_pilot} days, which makes it seem like it's not going to be released.

            To reduce clutter, please consider releasing it, deleting it, or deleting the whole title if it's no longer needed.

            If this is intentional, you can ignore this monthly message.
            MSG
            send_email to: title_obj.contact_email, subject: 'Unreleased Pilot Notification', msg: email_msg
          end # each title
          log_info 'Maint: Done notifying admins about old unreleased pilots'
        end

        # how many days can a version be deprecated?
        # @return [Integer] the number of days a version can be deprecated
        ################################
        def deprecated_lifetime_days
          @deprecated_lifetime_days ||= Xolo::Server.config.deprecated_lifetime_days || DFT_DEPRECATED_LIFETIME_DAYS
        end

        # Notify the admins about unreleased pilots when the newest one is older than
        # this many days.
        def unreleased_pilots_notification_days
          @unreleased_pilots_notification_days ||=
            Xolo::Server.config.unreleased_pilots_notification_days || DFT_UNRELEASED_PILOTS_NOTIFICATION_DAYS
        end

        # Shutdown the server
        # @return [void]
        ################################
        def shutdown_server(restart)
          # let all the routes know we are shutting down
          Xolo::Server.shutting_down = true

          progress "Server Shutdown by #{session[:admin]}", log: :info

          stop_maint_timer_task
          stop_log_rotation_timer_task
          shutdown_pkg_deletion_pool
          wait_for_object_locks
          wait_for_progress_streams

          # without unloading the launchd job, the server will restart automatically
          # when we tell it to quit
          if restart
            progress 'Restarting the server now', log: :info
            Xolo::Server::App.quit!
          else
            progress 'Shutting down the server now', log: :info
            unload_server_launchd
          end
        end

        # full shutdown of the server by unloading the launchd plist
        # @return [void]
        ################################
        def unload_server_launchd
          log_info 'Unloading the server launchd plist'
          system "/bin/launchctl unload #{SERVER_LAUNCHD_PLIST}"
        end

        # Stop the maintenance timer task
        # @return [void]
        ################################
        def stop_maint_timer_task
          progress 'Stopping the maint timer task', log: :info
          Xolo::Server::Helpers::Maintenance.maint_timer_task.shutdown
        end

        # Stop the log rotation timer task
        # @return [void]
        ################################
        def stop_log_rotation_timer_task
          progress 'Stopping the log rotation timer task', log: :info
          Xolo::Server::Log.log_rotation_timer_task.shutdown
        end

        # Wait for all object locks to be released
        # @return [void]
        ################################
        def wait_for_object_locks
          Xolo::Server.remove_expired_object_locks

          until Xolo::Server.object_locks.empty?
            progress 'Waiting for object locks to be released', log: :info
            log_debug "Object locks: #{Xolo::Server.object_locks.inspect}"
            sleep 5
            Xolo::Server.remove_expired_object_locks
          end
          progress 'All object locks released', log: :info
        end

        # Wait for all progress streams to finish
        # @return [void]
        ################################
        def wait_for_progress_streams
          prefix = Xolo::Server::Helpers::ProgressStreaming::PROGRESS_THREAD_NAME_PREFIX
          prog_threads = Thread.list.select { |th| th.name.to_s.start_with? prefix }
          # remove our own thread from the list
          prog_threads.delete Thread.current
          prog_threads.delete @streaming_thread

          until prog_threads.empty?
            progress 'Waiting for progress streams to finish', log: :info
            log_debug "Progress stream threads: #{prog_threads.map(&:name)}}"
            sleep 5
            prog_threads = Thread.list.select { |th| th.name.to_s.start_with? prefix }
            # remove our own thread from the list
            prog_threads.delete Thread.current
            prog_threads.delete @streaming_thread
          end
          progress 'All progress streams finished', log: :info
        end

        # Shutdown the pkg deletion pool
        # @return [void]
        ################################
        def shutdown_pkg_deletion_pool
          # Start the shutdown of the pkg_deletion_pool. Will finish anything
          # in the queue, but not accept any new tasks.
          pkg_pool = Xolo::Server::Version.pkg_deletion_pool
          pkg_pool.shutdown
          pkg_pool_shutdown_start = Time.now
          progress 'Shutting down pkg deletion pool', log: :info
          # returns true when shutdown is complete
          until pkg_pool.wait_for_termination(20)
            msg = "..Waiting for pkg deletion pool to finish, processing: #{pkg_pool.length}, in queue: #{pkg_pool.queue_length}"
            progress msg, log: :debug
            next unless Time.now - pkg_pool_shutdown_start > Xolo::Server::Constants::MAX_JAMF_WAIT_FOR_PKG_DELETION

            msg = 'ERROR: Timeout waiting for pkg deletion pool to finish, some pkgs may not be deleted'
            progress msg, log: :error
            pkg_pool.kill
            break
          end
          progress 'Pkg deletion queue is empty'
        end

      end # module Maintenance

    end # module Helpers

  end #  Server

end # module
