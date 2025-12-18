# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

# frozen_string_literal: true

# main module
module Xolo

  # Server Module
  module Server

    module Routes

      # See comments for Xolo::Server::Helpers::TitleEditor
      #
      module Subscriptions

        # This is how we 'mix in' modules to Sinatra servers
        # for route definitions and similar things
        #
        # (things to be 'included' for use in route and view processing
        # are mixed in by delcaring them to be helpers)
        #
        # We make them extentions here with
        #    extend Sinatra::Extension (from sinatra-contrib)
        # and then 'register' them in the server with
        #    register Xolo::Server::<Module>
        # Doing it this way allows us to split the code into a logical
        # file structure, without re-opening the Sinatra::Base server app,
        # and let xeitwork do the requiring of those files
        extend Sinatra::Extension

        # Module methods
        #
        ##############################
        ##############################

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # when this module is extended
        def self.extended(extender)
          Xolo.verbose_extend extender, self
        end

        # Routes
        #
        ##############################
        ##############################

        # This endpoint receives Jamf Webhook PatchSoftwareTitleUpdated events
        # from the Jamf Pro server, indicating that a subscribed title has a new version available
        # If the title is subscribed in Xolo, this creates a new xolo version for the title,
        # and either notifies the contact email for the title, or uses autopkg to get an installer.
        #
        # The body will be JSON like this:
        # {
        #   "event": {
        #     "jssID": integer,
        #     "lastUpdate": epoch,
        #     "latestVersion": "string",
        #     "name": "string",
        #     "reportUrls": [
        #       "string",
        #       "string"
        #     ]
        #   },
        #   "webhook": {
        #     "eventTimestamp": epoch,
        #     "id": integer,
        #     "name": "string",
        #     "webhookEvent": "PatchSoftwareTitleUpdated"
        #   }
        # }
        #
        # Some real data:
        #  {
        #    "event": {
        #      "name": "Xolo Testing",
        #      "latestVersion": "1.0.3",
        #      "lastUpdate":1765926131000,
        #      "jssID": 145,
        #      "reportUrls": [
        #        "https://casper.pixar.com:8443//patch.html?id=145&o=r"
        #      ]
        #    },
        #    "webhook": {
        #      "id": 4,
        #      "name": "PatchSoftwareTitleUpdated",
        #      "webhookEvent": "PatchSoftwareTitleUpdated",
        #      "eventTimestamp":1765926428322
        #    }
        #  }
        #
        # NOTE: The above reportUrls is incorrect on modern Jamf Pro servers.
        # the correct one would be https://casper.pixar.com:8443/view/computers/patch/145?tab=report
        #
        ###############
        post '/subscribed-title-updates' do
          request.body.rewind
          process_patch_title_updated_webhook(request.body.read)

          # always return 200 to the webhook sender
          status 200
          resp = { status: 200, message: 'Webhook event received' }
          body resp
        end

      end # Module

    end #  Routes

  end #  Server

end # module Xolo
