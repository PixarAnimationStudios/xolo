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

        # TODO: remove this stuff when the JPAPI/ruby-jss properly supports Patch Titles

        JPAPI_PATCH_TITLE_ENDPOINT = 'v2/patch-software-title-configurations'

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

        # Subscribe to a title on a given patch source.
        # @param source_id [Integer] the id or name of the patch source in Jamf
        # @param name_id [Integer] the name_id of the title on that patch source
        # @param display_name [String] an display name for the title
        # @return [Integer] the id of the new subscribed title, or false on failure
        #####################################
        def subscribe_to_title(source_id:, name_id:, display_name:)
          new_sub = Jamf::PatchTitle.create name: display_name, source_id: source_id, name_id: name_id

          new_sub.save
        end

      end # Subscriptions

    end # Helpers

  end # Server

end # module Xolo
