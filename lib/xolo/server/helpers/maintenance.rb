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

module Xolo

  module Server

    module Helpers

      # Nightly cleanup of deprecated and skipped packages.
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

        # At what hour should the nightly cleanup run?
        CLEANUP_HOUR = 2

        # on which day of the month should we send the unreleased pilot notifications?
        UNRELEASED_PILOTS_NOTIFICATION_DAY = 1

        # Once a version becomes deprecated, it will
        # be automatically deleted this many days later.
        # If not set in the server config, this is
        # the default value.
        # use 0 or less to disable cleanup of deprecated versions
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

        # A mutex for the cleanup process
        #
        # TODO: use Concrrent Ruby instead of Mutex
        #
        # @return [Mutex] the mutex
        #####################
        def self.cleanup_mutex
          @cleanup_mutex ||= Mutex.new
        end

        # nightly cleanup is done by a Concurrent::TimerTask, which checks every
        # hour to see if it should do anything.
        #
        # It will only do the cleanup if the current time is in the 2am hour
        # (02:00 - 02:59)
        #
        # We trigger the cleanup by POSTing to /cleanup, so that it runs
        # in the context of a request, having access to Title and Version instantiation.
        #
        # @return [Concurrent::TimerTask] the timed task to do log rotation
        ######################################
        def self.cleanup_timer_task
          return @cleanup_timer_task if @cleanup_timer_task

          @cleanup_timer_task =
            Concurrent::TimerTask.new(execution_interval: 3600) { post_to_start_cleanup }

          Xolo::Server.logger.info 'Created Concurrent::TimerTask for nightly cleanup.'
          @cleanup_timer_task
        end

        # When was our last cleanup?
        # @return [Time] the time of the last cleanup, or the epoch if never
        ######################################
        def self.last_cleanup
          @last_cleanup ||= Time.at(0)
        end

        # Set the time of the last cleanup
        # @param time [Time] the time of the last cleanup
        # @return [Time] the time of the last cleanup
        ######################################
        def self.last_cleanup=(time)
          @last_cleanup = time
        end

        # post to the server to start the cleanup process
        # This is done so that the cleanup can run in the context of a request,
        # having access to Title and Version instantiation.
        #
        # @param force [Boolean] force the cleanup to run now
        # @return [void]
        ######################################
        def self.post_to_start_cleanup(force: false)
          if Xolo::Server.shutting_down?
            Xolo::Server.logger.info 'Not starting cleanup, server is shutting down'
            return
          end

          # only run the cleanup if it's between 2am and 3am
          # and the last one was more than 23 hrs ago
          last_cleanup_hrs_ago = (Time.now - last_cleanup) / 3600
          return unless force || (Time.now.hour == CLEANUP_HOUR && last_cleanup_hrs_ago > 23)

          uri = URI.parse "https://#{Xolo::Server::Helpers::Auth::IPV4_LOOPBACK}/maint/cleanup-internal"
          https = Net::HTTP.new(uri.host, uri.port)
          https.use_ssl = true
          # The server cert may be self-signed and/or doesn't
          # match the hostname, so we need to disable verification
          https.verify_mode = OpenSSL::SSL::VERIFY_NONE

          request = Net::HTTP::Post.new(uri.path)
          request['Authorization'] = Xolo::Server::Helpers::Auth.internal_auth_token_header

          response = https.request(request)
          Xolo::Server.logger.info "Cleanup request response: #{response.code} #{response.body}"
        end

        # Cleanup things that need to be cleaned up
        # @return [void]
        ################################
        def run_cleanup
          if Xolo::Server.shutting_down?
            log_info 'Cleanup: Not starting cleanup, server is shutting down'
            return
          end
          # TODO: Use Concurrent ruby rather than this instance variable
          mutex = Xolo::Server::Helpers::Maintenance.cleanup_mutex

          if mutex.locked?
            log_warn 'Cleanup: already running, skipping this run'
            return
          end
          mutex.lock
          log_info 'Cleanup: starting'

          # add new cleanup tasks/methods here
          accept_title_editor_eas
          cleanup_versions

          log_info 'Cleanup: complete'
        ensure
          mutex&.unlock
        end

        # look for any titles that need their Title Editor EA's accepted,
        # and auto accept them if we need to
        # @return [void]
        ######################################
        def accept_title_editor_eas
          unless Xolo::Server.config.jamf_auto_accept_xolo_eas
            log_info 'Cleanup: The xolo server is not configured to auto-accept Title Editor EAs'
            return
          end

          log_info 'Cleanup: Looking for Title Editor EAs to auto-accept'

          # TODO: Be DRY with this stuff and similar in title_jamf_access.rb
          Xolo::Server::Title.all_titles.each do |title|
            title_obj = instantiate_title title
            next unless title_obj.jamf_patch_ea_awaiting_acceptance?

            log_info "Cleanup: Auto-accepting Title Editor EA for title '#{title}'"
            title_obj.accept_patch_ea_in_jamf_via_api
          rescue StandardError => e
            log_error "Cleanup: Error auto-accepting Title Editor EA for title '#{title}': #{e}"
          end # Xolo::Server::Title.all_titles.each

          log_info 'Cleanup: Done with Title Editor EAs to auto-accept'
        end

        # Cleanup versions.
        # @return [void]
        ################################
        def cleanup_versions
          log_info 'Cleanup: cleaning up deprecated and skipped versions'

          Xolo::Server::Title.all_titles.each do |title|
            title_obj = instantiate_title title

            title_obj.version_objects.each do |version|
              if version.deprecated?
                cleanup_deprecated_version version
              elsif version.skipped?
                cleanup_skipped_version version
              end # case
            end # each version

            notify_admins_of_unreleased_pilots(title_obj)
          end # each title

          Xolo::Server::Helpers::Maintenance.last_cleanup = Time.now
          log_info 'Cleanup: versions cleanup complete'
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

          log_info "Cleanup: Deleting deprecated version '#{version.version}' of title '#{version.title}'"
          version.delete
        end

        # Cleanup a skipped version.
        # @param version [Xolo::Server::Version] the version to cleanup
        # @return [void]
        ################################
        def cleanup_skipped_version(version)
          return if Xolo::Server.config.keep_skipped_versions

          log_info "Cleanup: Deleting skipped version '#{version.version}' of title '#{version.title}'"
          version.delete
        end

        # Notify the admins about unreleased pilots if needed
        # @return [void]
        ################################
        def notify_admins_of_unreleased_pilots(title_obj)
          return unless Time.now.day == UNRELEASED_PILOTS_NOTIFICATION_DAY
          return unless unreleased_pilots_notification_days.positive?
          return unless title_obj.latest_version

          latest_vers_obj = instantiate_version title: title_obj, version: title_obj.latest_version
          return unless latest_vers_obj.pilot?

          days_in_pilot = ((Time.now - latest_vers_obj.creation_date) / 86_400).to_i

          return unless days_in_pilot > unreleased_pilots_notification_days

          alert_msg = "Cleanup: Notifying #{title_obj.contact_email} about unreleased pilot '#{latest_vers}' of title '#{title_obj.title}', in pilot for #{days_in_pilot} days"

          log_info alert_msg
          send_alert alert_msg

          email_msg = <<~MSG
            The newest version '#{latest_vers_obj.version}' of title '#{title_obj.title}' has been in pilot for #{days_in_pilot} days, which makes it seem like it's not going to be released.

            To reduce clutter, please consider releasing it, deleting it, or deleting the whole title if it's no longer needed.

            If this is intentional, you can ignore this monthly message.
          MSG
          send_email to: title_obj.contact_email, subject: 'Unreleased Pilot Notification', msg: email_msg
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

          stop_cleanup_timer_task
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

        # Stop the cleanup timer task
        # @return [void]
        ################################
        def stop_cleanup_timer_task
          progress 'Stopping the cleanup timer task', log: :info
          Xolo::Server::Helpers::Maintenance.cleanup_timer_task.shutdown
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
