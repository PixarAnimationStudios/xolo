# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#
#

# frozen_string_literal: true

# main module
module Xolo

  module Server

    module Helpers

      # This is mixed in to Xolo::Server::App (as a helper, available in route processing)
      #
      # This holds methods and constants for working with subscribed titles - those
      # that are managed by other Non-Xolo Patch Sources.
      #
      module Subscriptions

        # Constants
        #####################
        #####################

        # Module Methods
        #######################
        #######################

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # Instance Methods
        #######################
        ######################

        # All available (i.e. not yet subscribed) titles on all patch sources defined in Jamf.
        # @return [Array<Hash>] the available titles and their sources
        #####################################
        def available_titles_for_subscription
          available = []

          Jamf::PatchSource.all(cnx: jamf_cnx).each do |ps|
            log_debug "Checking Patch Source #{ps} for available titles"
            ps = Jamf::PatchSource.fetch id: ps[:id], cnx: jamf_cnx
            ps.available_titles.each do |t|
              data = t.merge({ source_id: ps.id, source_name: ps.name })
              available << data
            end
          end

          available
        end

        # Process an incoming webhook event, possibly for a subscribed title
        # Do this in a thread so that we can return a 200 response to the webhook immediately,
        # and do the processing asynchronously (which may involve time-consuming tasks like autopkg runs)
        #################################
        def process_patch_title_updated_webhook(req_body)
          @process_webhook_thread = Thread.new do
            log_debug "Using a thread for processing PatchSoftwareTitleUpdated webhook event with body: #{req_body}"

            event_data = parse_json(req_body)[:event]

            title_name = event_data[:name]
            title_id = event_data[:jssID]
            new_version = event_data[:latestVersion]

            log_debug "Received PatchSoftwareTitleUpdate webhook event for patch title '#{title_name}' (jamf id #{title_id}), new version '#{new_version}'"

            subscribed_title = subscribed_title_objects.select { |tobj| tobj.jamf_patch_title_id.to_i == title_id.to_i }.first

            if subscribed_title
              msg = +"New version '#{new_version}' is available for subscribed title '#{subscribed_title.title}' (#{subscribed_title.display_name})."

              msg << " Running autopkg recipe '#{subscribed_title.autopkg_recipe}'." if subscribed_title.autopkg_enabled?

              log_info msg

              Xolo::Server::Version.add_version_via_subscription(
                title_object: subscribed_title,
                new_version: new_version
              )
            else
              log_debug "Title '#{title_name}' ID #{title_id} is not a subscribed title in Xolo. Ignoring webhook."
            end
          rescue => e
            msg = "Error processing PatchSoftwareTitleUpdated webhook event: #{e.class}: #{e}"
            log_error msg
            raise e, msg
          end # thread
        end

        # TODO: Delete this method after confirming we don't want it
        # It wasn't in use when it was commented out.
        #
        # Subscribe to a title on a given patch source.
        # @param source_id [Integer] the id or name of the patch source in Jamf
        # @param name_id [Integer] the name_id of the title on that patch source
        # @param display_name [String] an display name for the title
        # @return [Integer] the id of the new subscribed title, or false on failure
        #####################################
        # def subscribe_to_title(source_id:, name_id:, display_name:)
        #   new_sub = Jamf::PatchTitle.create name: display_name, source_id: source_id, name_id: name_id, cnx: jamf_cnx

        #   new_sub.save
        # end

      end # Subscriptions

    end # Helpers

  end # Server

end # module Xolo
