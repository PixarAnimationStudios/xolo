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
      # - run recipe
      # - move pkg to workspace
      # - sign pkg if needed
      # - wrap and re-sign if needed
      # - rename pkg
      # - upload to Jamf Pro
      #
      module AutoPkg

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

        #
        ##############################
        def upload_pkg_to_jamf_via_autopkg
          nil
        end

        # Handle a pkg from autopkg
        # move to file_transfers?
        ###########################################
        def process_autopkg_pkg(_pkg_file)
          nil
        end

      end # AutoPkg

    end # Helpers

  end # Server

end # module Xolo
