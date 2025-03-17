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
#

# frozen_string_literal: true

# main module
module Xolo

  module Admin

    # A version/patch as used by xadm.
    # This adds cli and walkthru UI, as well as
    # an interface to the Xolo Server for Title
    # objects.
    class Version < Xolo::Core::BaseClasses::Version

      # This is the server path for dealing with titles
      # POST to add a new one
      # GET to get a list of versions for a title
      # GET .../<version> to get the data for a single version
      # PUT .../<version> to update a version with new data
      # DELETE .../<version> to delete a version from the title
      SERVER_ROUTE = "/titles/#{Xolo::Admin::Options::TARGET_TITLE_PLACEHOLDER}/versions"

      # Server route for uploading packages
      UPLOAD_PKG_ROUTE = 'pkg'

      # Class Methods
      #############################
      #############################

      # @return [Hash{Symbol: Hash}] The ATTRIBUTES that are available as CLI & walkthru options
      def self.cli_opts
        @cli_opts ||= ATTRIBUTES.select { |_k, v| v[:cli] }
      end

      # get the server route to a specific version (or the version list) for a title
      # @param title [String] the title
      # @param version [String] the version to fetch
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Xolo::Admin::Title]
      ####################
      def self.server_route(title, version = nil)
        route = SERVER_ROUTE.sub(Xolo::Admin::Options::TARGET_TITLE_PLACEHOLDER, title)
        route << "/#{version}" if version
        route
      end

      # @return [Array<String>] The currently known versions of a title on the server
      #############################
      def self.all_versions(title, cnx)
        resp = cnx.get server_route(title)
        resp.body
      end

      # @return [Array<Xolo::Admin::Version>] The currently known versions of a title on the server
      #############################
      def self.all_version_objects(title, cnx)
        resp = cnx.get server_route(title)
        resp.body.map { |vd| Xolo::Admin::Version.new vd }
      end

      # Does a version of a title exist on the server?
      # @param title [String] the title
      # @param version [String] the version
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Boolean]
      #############################
      def self.exist?(title, version, cnx)
        all_versions(title, cnx).include? version
      end

      # Fetch a version of a title from the server
      # @param title [String] the title
      # @param version [String] the version to fetch
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Xolo::Admin::Title]
      ####################
      def self.fetch(title, version, cnx)
        resp = cnx.get server_route(title, version)
        new resp.body
      end

      # Deploy a version to desired computers and groups via MDM
      #
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @param groups [Array<String, Integer>] The groups to deploy to
      # @param computers [Array<String, Integer>] The computers to deploy to
      #
      # @return [Hash] The response from the server
      ####################
      def self.deploy(title, version, cnx, groups: [], computers: [])
        raise ArgumentError, 'Must provide at least one group or computer' if groups.pix_empty? && computers.pix_empty?

        route = "#{server_route(title, version)}/deploy"
        content = { groups: groups, computers: computers }
        resp = cnx.post(route) { |req| req.body = content }
        resp.body
      end

      # Delete a version of a title from the server
      # @param title [String] the title
      # @param version [String] the version to delete
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response body, parsed JSON
      ####################
      def self.delete(title, version, cnx)
        resp = cnx.delete server_route(title, version)
        resp.body
      end

      # Attributes
      ######################
      ######################

      # Constructor
      ######################
      ######################

      # Instance Methods
      #############################
      #############################

      # The server route for this version, after it exists on the server

      # Add this version to the server
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response from the server
      ####################
      def add(cnx)
        resp = cnx.post self.class.server_route(title), to_h
        resp.body
      end

      # Update this version to the server
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response from the server
      ####################
      def update(cnx)
        resp = cnx.put self.class.server_route(title, version), to_h
        resp.body
      end

      # Delete this title from the server
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response from the server
      ####################
      def delete(cnx)
        self.class.delete title, version, cnx
        # already returns resp.body
      end

      # Fetch a hash of URLs for the GUI pages for this title
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash{String => String}] page_name => url
      ####################
      def gui_urls(cnx)
        resp = cnx.get "#{self.class.server_route(title, version)}/urls"
        resp.body
      end

      # Upload a .pkg (or zipped bundle pkg) for this version
      # At this point, the jamf_pkg_file attribute
      # will containt the local file path.
      #
      # @param upload_cnx [Xolo::Admin::Connection] The server connection
      #
      # @return [Faraday::Response] The server response
      ##################################
      def upload_pkg(upload_cnx)
        return unless pkg_to_upload.is_a? Pathname

        # route = "#{UPLOAD_PKG_ROUTE}/#{title}/#{version}"
        route = "#{self.class.server_route(title, version)}/#{UPLOAD_PKG_ROUTE}"

        # TODO: Update this to the more modern correct class
        # upfile = Faraday::UploadIO.new(
        #   pkg_to_upload.to_s,
        #   'application/octet-stream',
        #   pkg_to_upload.basename.to_s
        # )

        upfile = Faraday::Multipart::FilePart.new(pkg_to_upload.expand_path.to_s, 'application/octet-stream')

        content = { file: upfile }
        upload_cnx.post(route) { |req| req.body = content }
      end

      # Get the Patch Report data for this version
      # It's the JPAPI report data with each hash having a frozen: key added
      #
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Array<Hash>] Data for each computer with this version of this title installed
      ##################################
      def patch_report_data(cnx)
        resp = cnx.get "#{self.class.server_route(title, version)}/patch_report"
        resp.body
      end

    end # class Title

  end # module Admin

end # module Xolo
