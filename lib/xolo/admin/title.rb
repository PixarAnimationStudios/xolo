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
#

# frozen_string_literal: true

# main module
module Xolo

  module Admin

    # A title used by xadm.
    #
    # These are instantiated with data from the server
    # (for existing Titles) or from the xadm CLI opts
    # or walkthru process.
    #
    # This class also defines how xadm communicates
    # title data to and from the server.
    class Title < Xolo::Core::BaseClasses::Title

      # Constants
      #############################
      #############################

      # This is the server path for dealing with titles
      # POST to add a new one
      # GET to get a list of titles
      # GET .../<title> to get the data for a single title
      # PUT .../<title> to update a title with new data
      # DELETE .../<title> to delete a title and its version
      SERVER_ROUTE = '/titles'

      UPLOAD_ICON_ROUTE = '/upload/ssvc-icon'

      # Class Methods
      #############################
      #############################

      # @return [Hash{Symbol: Hash}] The ATTRIBUTES that are available as CLI & walkthru options
      def self.cli_opts
        @cli_opts ||= ATTRIBUTES.select { |_k, v| v[:cli] }
      end

      # @return [Array<String>] The currently known titles names on the server
      #############################
      def self.all_titles(cnx)
        resp = cnx.get SERVER_ROUTE
        resp.body.map { |t| t[:title] }
      end

      # @return [Array<Xolo::Admin::Title>] The currently known titles on the server
      #############################
      def self.all_title_objects(cnx)
        resp = cnx.get SERVER_ROUTE
        resp.body.map { |td| Xolo::Admin::Title.new td }
      end

      # Does a title exist on the server?
      # @param title [String] the title
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Boolean]
      #############################
      def self.exist?(title, cnx)
        all_titles(cnx).include? title
      end

      # Fetch a title from the server
      # @param title [String] the title to fetch
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Xolo::Admin::Title]
      ####################
      def self.fetch(title, cnx)
        resp = cnx.get "#{SERVER_ROUTE}/#{title}"

        new resp.body
      end

      # Delete a title from the server
      # @param title [String] the title to delete
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response data
      ####################
      def self.delete(title, cnx)
        resp = cnx.delete "#{SERVER_ROUTE}/#{title}"
        resp.body
      end

      # the latest version of a title in Xolo
      # @param title [String] the title we care about
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [void]
      ####################
      def self.latest_version(title, cnx)
        resp = cnx.get "#{SERVER_ROUTE}/#{title}"
        resp.body[:version_order].first
      end

      # Attributes
      ######################
      ######################

      # Constructor
      ######################
      ######################

      # Read in the contents of any version script given
      def initialize(data_hash)
        super
        # @self_service_icon = nil if @self_service_icon == Xolo::ITEM_UPLOADED

        return unless version_script
        return if version_script == Xolo::ITEM_UPLOADED

        @version_script = version_script.read
      end

      # Instance Methods
      #############################
      #############################

      # Add this title to the server
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response body from the server
      ####################
      def add(cnx)
        resp = cnx.post SERVER_ROUTE, to_h
        resp.body
      end

      # Update this title to the server
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response body from the server
      ####################
      def update(cnx)
        resp = cnx.put "#{SERVER_ROUTE}/#{title}", to_h
        resp.body
      end

      # Delete this title from the server
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response data
      ####################
      def delete(cnx)
        self.class.delete title, cnx
      end

      # the latest version of this title in Xolo
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [String]
      ####################
      def latest_version(cnx)
        self.class.latest_version(title, cnx)
      end

      # Upload an icon for self service.
      # At this point, the self_service_icon attribute
      # will containt the local file path.
      #
      # @param upload_cnx [Xolo::Admin::Connection] The server connection
      #
      # @return [Faraday::Response] The server response
      ##################################
      def upload_self_service_icon(upload_cnx)
        return if self_service_icon.pix_blank?
        return if self_service_icon == Xolo::ITEM_UPLOADED

        route = "#{UPLOAD_ICON_ROUTE}/#{title}"

        upfile = Faraday::UploadIO.new(
          self_service_icon.to_s,
          'application/octet-stream',
          self_service_icon.basename.to_s
        )

        content = { file: upfile }
        upload_cnx.post(route) { |req| req.body = content }
      end

      # Add more data to our hash
      ###########################
      def to_h
        super
      end

    end # class Title

  end # module Admin

end # module Xolo
