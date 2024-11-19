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

        # Module Methods
        #####################################

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
          # only run the cleanup if it's between 2am and 3am
          # and the last one was more than 23 hrs ago
          last_cleanup_hrs_ago = (Time.now - last_cleanup) / 3600
          return unless force || (Time.now.hour == CLEANUP_HOUR && last_cleanup_hrs_ago > 23)

          uri = URI.parse "https://#{Xolo::Server::Helpers::Auth::IPV4_LOOPBACK}/cleanup"
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

        # Cleanup versions.
        # @return [void]
        ################################
        def cleanup_versions
          log_info 'Running Cleanup...'

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
        end

        # Cleanup a deprecated version.
        # @param version [Xolo::Server::Version] the version to cleanup
        # @return [void]
        ################################
        def cleanup_deprecated_version(version)
          # do nothing if the deprecated_lifetime_days is 0 or less
          return unless deprecated_lifetime_days > 0

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
          return unless unreleased_pilots_notification_days.positive?

          latest_vers = title_obj.version_order&.first
          return unless latest_vers

          latest_version = title_obj.version_object latest_vers
          return unless latest_version.pilot?

          days_in_pilot = ((Time.now - latest_version.creation_date) / 86_400).to_i

          return unless days_in_pilot > unreleased_pilots_notification_days

          log_info "Cleanup: Notifying admins about unreleased pilot '#{latest_vers}' of title '#{title_obj.title}', in pilot for #{days_in_pilot} days"

          # TODO: how to do this? Email? Alert?
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

      end # module Maintenance

    end # module Helpers

  end #  Server

end # module
