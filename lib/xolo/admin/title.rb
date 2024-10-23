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

      UPLOAD_ICON_ROUTE = 'ssvc-icon'

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

      # Is the current admin allowed to set a title's release groups to 'all'?
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Boolean]
      ####################
      def self.release_to_all_allowed?(cnx)
        resp = cnx.get '/auth/release_to_all_allowed'
        resp.body
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

        @version_script = version_script.read if version_script.respond_to?(:read)
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
      def latest_version
        version_order&.first
      end

      # Freeze the one or more computers for this title
      # @param computers [Array<String>] the computers to freeze
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response data
      ####################
      def freeze(computers, cnx)
        resp = cnx.put "#{SERVER_ROUTE}/#{title}/freeze", computers
        resp.body
      end

      # Thaw the one or more computers for this title
      # @param computers [Array<String>] the computers to freeze
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response data
      ####################
      def thaw(computers, cnx)
        resp = cnx.put "#{SERVER_ROUTE}/#{title}/thaw", computers
        resp.body
      end

      # Fetch the frozen computers for this title
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash{String => String}] computer name => user name
      ####################
      def frozen(cnx)
        resp = cnx.get "#{SERVER_ROUTE}/#{title}/frozen"
        resp.body
      end

      # Fetch a hash of URLs for the GUI pages for this title
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash{String => String}] page_name => url
      ####################
      def gui_urls(cnx)
        resp = cnx.get "#{SERVER_ROUTE}/#{title}/urls"
        resp.body
      end

      # Upload an icon for self service.
      # At this point, the self_service_icon attribute
      # should contain the local file path.
      #
      # @param upload_cnx [Xolo::Admin::Connection] The server connection
      #
      # @return [Faraday::Response] The server response
      ##################################
      def upload_self_service_icon(upload_cnx)
        return unless self_service_icon.is_a? Pathname

        unless self_service_icon.readable?
          raise Xolo::Core::Exceptions::NoSuchItemError,
                "Can't upload self service icon '#{self_service_icon}': file doesn't exist or is not readable"
        end

        # upfile = Faraday::UploadIO.new(
        #   self_service_icon.to_s,
        #   'application/octet-stream',
        #   self_service_icon.basename.to_s
        # )

        mimetype = `/usr/bin/file --brief --mime-type #{Shellwords.escape self_service_icon.expand_path.to_s}`.chomp
        upfile = Faraday::Multipart::FilePart.new(self_service_icon.expand_path.to_s, mimetype)
        content = { file: upfile }
        # route =  "#{UPLOAD_ICON_ROUTE}/#{title}"
        route = "#{SERVER_ROUTE}/#{title}/#{UPLOAD_ICON_ROUTE}"

        upload_cnx.post(route) { |req| req.body = content }
      end

      # Get the patch report data for this title
      # It's the JPAPI report data with each hash having a frozen: key added
      #
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Array<Hash>] Data for each computer with any version of this title installed
      ##################################
      def patch_report_data(cnx)
        resp = cnx.get "#{SERVER_ROUTE}/#{title}/patch_report"
        resp.body
      end

      # Add more data to our hash
      ###########################
      def to_h
        super
      end

    end # class Title

  end # module Admin

end # module Xolo
