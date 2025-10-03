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

      TARGET_TITLE_PLACEHOLDER = 'TARGET_TITLE_PH'

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
      rescue Faraday::ResourceNotFound
        raise Xolo::NoSuchItemError, "No such title '#{title}'"
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

      # Release a version of this title.
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @param version [String] the version to release
      # @return [Hash] the response body from the server
      ####################
      def release(cnx, version:)
        resp = cnx.patch "#{SERVER_ROUTE}/#{title}/release/#{version}", {}
        resp.body
      end

      # Repair this title, and optionally all its versions
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @param versions [Boolean] if true, repair all versions of this title
      # @return [Hash] the response body from the server
      ####################
      def repair(cnx, versions: false)
        resp = cnx.post "#{SERVER_ROUTE}/#{title}/repair", { repair_versions: versions }
        resp.body
      end

      # Delete this title from the server
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response data
      ####################
      def delete(cnx)
        self.class.delete title, cnx
      end

      # Freeze the one or more computers for this title
      # @param computers [Array<String>] the computers to freeze
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response data
      ####################
      def freeze(targets, users = false, cnx)
        data = { targets: targets, users: users }
        resp = cnx.put "#{SERVER_ROUTE}/#{title}/freeze", data
        resp.body
      end

      # Thaw the one or more computers for this title
      # @param computers [Array<String>] the computers to freeze
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Hash] the response data
      ####################
      def thaw(targets, users = false, cnx)
        data = { targets: targets, users: users }
        resp = cnx.put "#{SERVER_ROUTE}/#{title}/thaw", data
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

      # The change log is a list of hashes, each with keys:
      # :time, :admin, :ipaddr, :version (may be nil), :action
      #
      # @param cnx [Faraday::Connection] The connection to use, must be logged in already
      # @return [Array<Hash>] The change log for this title
      ####################
      def changelog(cnx)
        resp = cnx.get "#{SERVER_ROUTE}/#{title}/changelog"
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
          raise Xolo::NoSuchItemError,
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
