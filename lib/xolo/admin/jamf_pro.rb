# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#
#

# frozen_string_literal: true

# main module
module Xolo

  module Admin

    # Stuff that works with data from the Jamf Pro server
    # via the Xolo Server
    #
    module JamfPro

      # Constants
      ##########################
      ##########################

      JAMF_ROUTE_BASE = '/jamf'

      # Xolo server route to the list of package names
      PACKAGE_NAME_ROUTE = "#{JAMF_ROUTE_BASE}/package-names"

      # Xolo server route to the list of computer group names
      COMPUTER_GROUP_NAME_ROUTE = "#{JAMF_ROUTE_BASE}/computer-group-names"

      # Xolo server route to the list available categories
      CATEGORY_NAME_ROUTE = "#{JAMF_ROUTE_BASE}/category-names"

      # Module Methods
      ##########################
      ##########################

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # when this module is extended
      def self.extended(extender)
        Xolo.verbose_extend extender, self
      end

      # Instance Methods
      ##########################
      ##########################

      # @return [Array<String>] the names of all Package objects in Jamf Pro
      #######################
      def jamf_package_names
        @jamf_package_names ||= server_cnx.get(PACKAGE_NAME_ROUTE).body
      end

      # @return [Array<String>] the names of all ComputerGroup objects in Jamf Pro
      #######################
      def jamf_computer_group_names
        @jamf_computer_group_names ||= server_cnx.get(COMPUTER_GROUP_NAME_ROUTE).body
      end

      # @return [Array<String>] the names of all Categories in Jamf Pro.
      #######################
      def jamf_category_names
        @jamf_category_names ||= server_cnx.get(CATEGORY_NAME_ROUTE).body
      end

    end # module

  end # module Admin

end # module Xolo
