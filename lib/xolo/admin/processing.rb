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

    # Methods that execute the xadm commands and their options
    #
    module Processing

      # Constants
      ##########################
      ##########################

      # Title attributes that are used for 'xadm search'
      SEARCH_ATTRIBUTES = %i[title display_name description publisher app_name app_bundle_id].freeze

      # Routes for server admins

      SERVER_STATUS_ROUTE = '/maint/state'
      SERVER_CLENUP_ROUTE = '/maint/cleanup'
      SERVER_ROTATE_LOGS_ROUTE = '/maint/rotate-logs'
      SERVER_UPDATE_CLIENT_DATA_ROUTE = '/maint/update-client-data'
      SERVER_LOG_LEVEL_ROUTE = '/maint/set-log-level'
      SERVER_SHUTDOWN_ROUTE = '/maint/shutdown-server'

      # We can't pull this from Xolo::Server::Log::LEVELS, because
      # we don't want to require that file here, it'll complain about
      # the lack of sinatra and such.
      LOG_LEVELS = %w[debug info warn error fatal].freeze

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

      # Which opts to process, those from walkthru, or from the CLI?
      #
      # @return [OpenStruct] the opts to process
      #######################
      def opts_to_process
        @opts_to_process ||= walkthru? ? walkthru_cmd_opts : cli_cmd_opts
      end

      # puts a string to stdout, unless quiet? is true
      #
      # @param msg [String] the string to puts
      # @return [void]
      #########################
      def speak(msg)
        puts msg unless quiet?
      end

      # Search for a title in Xolo
      # Looks for the search string (case insensitive) in these attributes:
      #  - title
      #  - display_name
      #  - description
      #  - publisher
      #  - app_name
      #  - app_bundle_id
      #
      # will output the results showing those attributes
      #
      # If json? is true, will output the results as a JSON array of hashes
      # containing the full title object.
      #
      # @param search_str [String] the string to search for
      #
      # @return [void]
      ###############################
      def search_titles
        search_str = cli_cmd.title
        titles = Xolo::Admin::Title.all_title_objects(server_cnx)

        results = []
        titles.each do |t|
          next unless SEARCH_ATTRIBUTES.any? { |attr| t.send(attr).to_s =~ /#{search_str}/i }

          if json?
            results << t.to_h
            next
          end

          results << title_search_result_str(t, one_line: cli_cmd_opts.summary)
        end # titles.each

        # if json?, output it and we're done
        if json?
          puts JSON.pretty_generate(results)
          return
        end

        # no results?
        if results.empty?
          puts "# No titles matching '#{search_str}'"
          return
        end

        # results found
        puts "# All titles matching '#{search_str}'"
        if cli_cmd_opts.summary
          header = %w[Title Display Publisher Contact Versions]
          show_text generate_report(results, header_row: header, title: nil)
        else
          puts results.join("\n\n")
        end
      rescue StandardError => e
        handle_processing_error e
      end

      # From a title, get a String for use in a search report, either
      # multiline or single line
      # @param title [Xolo::Admin::Title] the title
      # @param one_line [Boolean] whether to use single line format
      # @return [String] the string to display for the search result
      ###################################
      def title_search_result_str(title, one_line: false)
        versions = versions_str(title)
        if one_line
          [title.title, title.display_name, title.publisher, title.contact_email, versions]
        else
          titleout = +'#---------------------------------------'
          titleout << "\nTitle: #{title.title}"
          titleout << "\nDisplay Name: '#{title.display_name}"
          titleout << "\nPublisher: #{title.publisher}"
          titleout << "\nApp: #{title.app_name}\nBundleID: #{title.app_bundle_id}" if title.app_name
          titleout << "\nVersions: #{versions}"
          titleout << "\nDescription:"
          titleout << "\n#{title.description}"
          titleout
        end # json?
      end

      # From a title, get a String with current versions of a title, comma separated
      # with the current released version marked
      # @param title [Xolo::Admin::Title] the title
      # @return [String] the versions string
      ##################################
      def versions_str(title)
        versions = []
        title.version_order.each do |v|
          versions <<
            if v.to_s == title.released_version.to_s
              "#{v} (released)"
            else
              v
            end
        end
        versions.join(', ')
      end

      # update the adm config file using the values from 'xadm config'
      # which is a walkthru
      #
      # @return [void]
      ###############################
      def update_config
        debug? && puts("DEBUG: opts_to_process: #{opts_to_process}")

        # Xolo::Admin::Configuration::KEYS.each_key do |key|
        #   config.send "#{key}=", opts_to_process[key]
        # end

        config.save_to_file data: opts_to_process.to_h
      end

      # List all titles in Xolo
      #
      # @return [void]
      ###############################
      def list_titles
        titles = Xolo::Admin::Title.all_title_objects(server_cnx)

        if json?
          puts JSON.pretty_generate(titles.map(&:to_h))
          return
        end

        if titles.empty?
          puts "# No Titles in Xolo! Add one with 'xadm add-title <title>'"
          return
        end

        report_title = 'All titles in Xolo'
        header = %w[Title Created By SSvc? Released Latest]
        data = titles.map do |t|
          [
            t.title,
            t.creation_date.to_date,
            t.created_by,
            t.self_service || false,
            t.released_version,
            t.latest_version
          ]
        end
        data.sort_by! { |d| d[0].downcase } # sort by title

        show_text generate_report(data, header_row: header, title: report_title)
      rescue StandardError => e
        handle_processing_error e
      end

      # Add a title to Xolo
      #
      # @return [void]
      ###############################
      def add_title
        return unless confirmed? "Add title '#{cli_cmd.title}'"

        opts_to_process.title = cli_cmd.title
        read_uninstall_script

        new_title = Xolo::Admin::Title.new opts_to_process

        response_data = new_title.add(server_cnx)

        if debug?
          puts "DEBUG: response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]

        # Upload the ssvc icon, if any?
        upload_ssvc_icon new_title

        speak "Title '#{cli_cmd.title}' has been added to Xolo.\nAdd at least one version to enable piloting and deployment"
      rescue StandardError => e
        handle_processing_error e
      end

      # Edit/Update a title in Xolo
      #
      # @return [void]
      ###############################
      def edit_title
        return unless confirmed? "Edit title '#{cli_cmd.title}'"

        opts_to_process.title = cli_cmd.title
        read_uninstall_script

        # if we were passed a new uninstall script, remove the uninstall ids
        if opts_to_process.uninstall_script && opts_to_process.uninstall_script != Xolo::ITEM_UPLOADED
          opts_to_process.uninstall_ids = []
        end

        # if we were passed uninstall ids, remove the uninstall script
        opts_to_process.uninstall_script = nil unless opts_to_process.uninstall_ids.pix_empty?

        title = Xolo::Admin::Title.new opts_to_process
        response_data = title.update server_cnx

        if debug?
          puts "DEBUG: response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]

        # Upload the ssvc icon, if any?
        upload_ssvc_icon title

        speak "Title '#{cli_cmd.title}' has been updated in Xolo."
      rescue StandardError => e
        handle_processing_error e
      end

      # if we have an uninstall script, read it in
      #
      # @return [void]
      ###############################
      def read_uninstall_script
        return unless opts_to_process.uninstall_script.to_s.start_with? '/'

        opts_to_process.uninstall_script = Pathname.new(opts_to_process.uninstall_script).read
      end

      # Upload the ssvc icon, if any?
      # TODO: progress feedback? Icons should never be very large, so
      # prob. not, to start with
      #
      # @param title [Xolo::Admin::Title] the title for which we are uploading an icon
      # @return [void]
      #######################
      def upload_ssvc_icon(title)
        return unless title.self_service_icon.is_a? Pathname

        speak "Uploading self-service icon #{title.self_service_icon.basename}, #{title.self_service_icon.pix_humanize_size} to Xolo."

        title.upload_self_service_icon(upload_cnx)

        speak 'Self-service icon uploaded. Will be added to Self Service policies as needed'
      rescue StandardError => e
        handle_processing_error e
      end

      # Delete a title in Xolo
      #
      # @return [void]
      ###############################
      def delete_title
        return unless confirmed? "Delete title '#{cli_cmd.title}' and all its versions"

        response_data = Xolo::Admin::Title.delete cli_cmd.title, server_cnx

        if debug?
          puts "DEBUG: response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]

        speak "Title '#{cli_cmd.title}' has been deleted from Xolo."
      rescue StandardError => e
        handle_processing_error e
      end

      # Freeze one or more computers for a title in Xolo
      #
      # @return [void]
      ###############################
      def freeze
        conf_msg = <<~ENDMSG
          Freeze computers for title '#{cli_cmd.title}'.
          They will not update beyond their installed version,
          even it the title is not installed at all.
        ENDMSG

        return unless confirmed? conf_msg

        title = Xolo::Admin::Title.fetch cli_cmd.title, server_cnx
        response_data = title.freeze ARGV, cli_cmd_opts.users_given, server_cnx

        if debug?
          puts "DEBUG: response_data: #{response_data}"
          puts
        end

        if json?
          puts JSON.pretty_generate(response_data)
          return
        end

        rpt_title = "Results for freezing Title '#{cli_cmd.title}'"
        header = %w[Computer Result]
        report = generate_report(response_data.to_a, header_row: header, title: rpt_title)
        show_text report
      rescue StandardError => e
        handle_processing_error e
      end

      # list the computers that are frozen for a title in Xolo
      #
      # @return [void]
      ###############################
      def list_frozen
        title = Xolo::Admin::Title.fetch cli_cmd.title, server_cnx
        frozen_computers = title.frozen server_cnx
        if debug?
          puts "DEBUG: response_data: #{frozen_computers}"
          puts
        end

        if json?
          puts JSON.pretty_generate(frozen_computers)
          return
        end

        if frozen_computers.empty?
          puts "# No computers are frozen for Title '#{cli_cmd.title}'"
          return
        end

        rpt_title = "Frozen Computers for Title '#{cli_cmd.title}'"
        header = %w[Computer User]
        report = generate_report(frozen_computers.to_a, header_row: header, title: rpt_title)
        show_text report
      rescue StandardError => e
        handle_processing_error e
      end

      # Thaw one or more computers for a title in Xolo
      #
      # @return [void]
      ###############################
      def thaw
        conf_msg = <<~ENDMSG
          Thaw computers for title '#{cli_cmd.title}'.
          They will again be able to update beyond their installed version.
        ENDMSG

        return unless confirmed? conf_msg

        title = Xolo::Admin::Title.fetch cli_cmd.title, server_cnx
        response_data = title.thaw ARGV, cli_cmd_opts.users_given, server_cnx

        if debug?
          puts "DEBUG: response_data: #{response_data}"
          puts
        end

        if json?
          puts JSON.pretty_generate(response_data)
          return
        end

        rpt_title = "Results for thawing Title '#{cli_cmd.title}'"
        header = %w[Computer Result]
        report = generate_report(response_data.to_a, header_row: header, title: rpt_title)
        show_text report
      rescue StandardError => e
        handle_processing_error e
      end

      # List all versions of a title in Xolo
      #
      # @return [void]
      ###############################
      def list_versions
        versions = Xolo::Admin::Version.all_version_objects(cli_cmd.title, server_cnx)

        if json?
          puts JSON.pretty_generate(versions.map(&:to_h))
          return
        end

        if versions.empty?
          puts "# No versions for Title '#{cli_cmd.title}'"
          return
        end

        report_title = "All versions of '#{cli_cmd.title}' in Xolo"
        header = %w[Vers Created By Released By Status]
        data = versions.sort_by(&:creation_date).map do |v|
          [
            v.version,
            v.creation_date.to_date,
            v.created_by,
            v.release_date&.to_date,
            v.released_by,
            v.status
          ]
        end
        show_text generate_report(data, header_row: header, title: report_title)
      rescue StandardError => e
        handle_processing_error e
      end

      # Add a version to a title to Xolo
      #
      # @return [void]
      ###############################
      def add_version
        return unless confirmed? "Add version '#{cli_cmd.version}' to title '#{cli_cmd.title}'"

        opts_to_process.title = cli_cmd.title
        opts_to_process.version = cli_cmd.version

        new_vers = Xolo::Admin::Version.new opts_to_process
        response_data = new_vers.add(server_cnx)

        if debug?
          puts "DEBUG: response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]

        # Upload the pkg, if any?
        upload_pkg(new_vers)
        speak 'It can take up to 15 minutes for the version to be available via Jamf and Self Service.'
      rescue StandardError => e
        handle_processing_error e
      end

      # Upload a pkg in a thread with indeterminate progress feedback
      # (i.e.  '...Upload in progress' )
      # Determining actual progress numbers
      # would require either a locol tool to meter the IO or a server
      # capable of sending it as a progress stream, neither of which
      # is straightforward.
      #
      # @param version [Xolo::Admin::Version] the version for which we are uploading
      #   the pkg. It must have a 'pkg_to_upload' that is a pathname to an existing
      #   file
      # @return [void]
      ################################
      def upload_pkg(version)
        return unless version.pkg_to_upload.is_a? Pathname

        speak "Uploading #{version.pkg_to_upload.basename}, #{version.pkg_to_upload.pix_humanize_size} to Xolo"
        # start the upload in a thread
        upload_thr = Thread.new { version.upload_pkg(upload_cnx) }

        # check the thread every second, but only update the terminal every 10 secs
        count = 0
        while upload_thr.alive?

          speak "... #{Time.now.strftime '%F %T'} Upload in progress" if (count % 10).zero?
          sleep 1
          count += 1
        end
        speak 'Upload complete, Final upload to distribution points will happen soon.'
      rescue StandardError => e
        handle_processing_error e
      end

      # Edit/Update a version in Xolo
      #
      # @return [void]
      ###############################
      def edit_version
        return unless confirmed? "Edit Version '#{cli_cmd.version}' of Title '#{cli_cmd.title}'"

        opts_to_process.title = cli_cmd.title
        opts_to_process.version = cli_cmd.version
        vers = Xolo::Admin::Version.new opts_to_process

        response_data = vers.update server_cnx

        if debug?
          puts "DEBUG: response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]

        # Upload the pkg, if any?
        upload_pkg(vers)

        speak "Version '#{cli_cmd.version}' of title '#{cli_cmd.title}' has been updated in Xolo."
      rescue StandardError => e
        handle_processing_error e
      end

      # Deploy a version of a title in Xolo to one or more computers or computer groups
      #
      # @return [void]
      ###############################
      def deploy_version
        return unless confirmed? "Deploy Version '#{cli_cmd.version}' of Title '#{cli_cmd.title}' via MDM?"

        unless json? || quiet?
          puts "Deploying Version '#{cli_cmd.version}' of Title '#{cli_cmd.title}' to computers: #{ARGV.join(', ')}"
          puts "Groups: #{opts_to_process[:groups].join(', ')}" unless opts_to_process[:groups].pix_empty?
        end

        response = Xolo::Admin::Version.deploy(
          cli_cmd.title,
          cli_cmd.version,
          server_cnx,
          groups: opts_to_process[:groups],
          computers: ARGV
        )

        return if quiet?

        if json?
          puts JSON.pretty_generate(response)
          return
        end

        puts "Results: Deployment of Version '#{cli_cmd.version}' of Title '#{cli_cmd.title}'"
        puts '---------------------------------------------------------------'
        response[:removals].each do |removal|
          type = removal[:device] ? 'Computer' : 'Group'
          name = removal[:device] || removal[:group]
          puts "Removed #{type} '#{name}' from targets: #{removal[:reason]}"
        end

        response[:queuedCommands].each do |cmd|
          puts "Sent MDM deployment to #{cmd[:device]}, Command UUID: #{cmd[:commandUuid]}"
        end

        response[:errors].each do |err|
          puts "Error deploying to #{err[:device]}: #{err[:reason]}"
        end
      rescue StandardError => e
        handle_processing_error e
      end

      # Delete a title in Xolo
      #
      # @return [void]
      ###############################
      def delete_version
        return unless confirmed? "Delete version '#{cli_cmd.version}' from title '#{cli_cmd.title}'"

        response_data = Xolo::Admin::Version.delete cli_cmd.title, cli_cmd.version, server_cnx

        if debug?
          puts "DEBUG: response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]
      rescue StandardError => e
        handle_processing_error e
      end

      # Release a version of a title in Xolo
      #
      # @return [void]
      ###############################
      def release_version
        return unless confirmed? "Release Version '#{cli_cmd.version}' of Title '#{cli_cmd.title}'"

        opts_to_process.title = cli_cmd.title

        title = Xolo::Admin::Title.new opts_to_process
        response_data = title.release server_cnx, version: cli_cmd.version

        if debug?
          puts "DEBUG: response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]
        speak "Version '#{cli_cmd.version}' of Title '#{cli_cmd.title}' has been released."
      rescue StandardError => e
        handle_processing_error e
      end

      # show the change log for a title
      #
      # @return [void]
      ###############################
      def show_changelog
        title = Xolo::Admin::Title.fetch cli_cmd.title, server_cnx
        changelog = title.changelog(server_cnx)
        if json?
          puts JSON.pretty_generate(changelog)
          return
        end

        output = ["# Changelog for Title '#{cli_cmd.title}'"]
        output << '#' * (output.first.length + 5)
        changelog.each do |change|
          vers_or_title = change[:version] ? "version #{change[:version]}" : 'title'
          output << "#{Time.parse(change[:time]).strftime('%F %T')} #{change[:admin]}@#{change[:host]} changed #{vers_or_title}"

          if change[:msg]
            val = format_multiline_indent(change[:msg], indent: 7)
            output << "  msg: #{val}"

          else
            output << "  Attribute: #{change[:attrib]}"
            from_val = format_multiline_indent(change[:old], indent: 8)
            output << "  From: #{from_val}"
            to_val = format_multiline_indent(change[:new], indent: 6)
            output << "  To: #{to_val}"
          end
          output << nil
        end

        show_text output.join("\n")
      rescue StandardError => e
        handle_processing_error e
      end

      # Show details about a title or version in xolo
      #
      # @return [void]
      ###############################
      def show_info
        cli_cmd.version ? show_version_info : show_title_info
      end

      # Show details about a title in xolo
      #
      # @return [void]
      ###############################
      def show_title_info
        title = Xolo::Admin::Title.fetch cli_cmd.title, server_cnx

        if json?
          puts title.to_json
          return
        end

        urls = title.gui_urls(server_cnx)

        puts "# Info for Title '#{cli_cmd.title}'"
        puts '###################################'

        Xolo::Admin::Title::ATTRIBUTES.each do |attr, deets|
          next if deets[:hide_from_info]
          # description is handled specially below
          next if attr == :description

          value = title.send attr
          value = value.join(Xolo::COMMA_JOIN) if value.is_a? Array
          puts "- #{deets[:label]}: #{value}".pix_word_wrap
        end
        puts '- Description:'
        title.description.lines.each { |line| puts "  #{line.chomp}" } unless title.description.pix_empty?

        puts '#'
        puts '# Web App URLs'
        puts '###################################'
        urls.each { |pagename, url| puts "#{pagename}: #{url}" }
      rescue StandardError => e
        handle_processing_error e
      end

      # Show details about a title in xolo
      #
      # @return [void]
      ###############################
      def show_version_info
        vers = Xolo::Admin::Version.fetch cli_cmd.title, cli_cmd.version, server_cnx

        if json?
          puts vers.to_json
          return
        end

        urls = vers.gui_urls(server_cnx)

        puts "# Info for Version #{cli_cmd.version} of Title '#{cli_cmd.title}'"
        puts '##################################################'

        Xolo::Admin::Version::ATTRIBUTES.each do |attr, deets|
          next if deets[:hide_from_info]

          value = vers.send attr
          value = value.join(Xolo::COMMA_JOIN) if value.is_a? Array
          puts "- #{deets[:label]}: #{value}".pix_word_wrap
        end

        puts '#'
        puts '# Web App URLs'
        puts '###################################'
        urls.each { |pagename, url| puts "#{pagename}: #{url}" }
        # rescue Faraday::ResourceNotFound
        # puts "No Such Version '#{cli_cmd.version}' of Title '#{cli_cmd.title}'"
      rescue StandardError => e
        handle_processing_error e
      end

      # Show the patch report for a title or version in xolo
      #
      # @return [void]
      ###############################
      def patch_report
        # since there is no actual version 'unknown'
        # we'll fetch all of them and extract the onese we want
        if cli_cmd.version == Xolo::UNKNOWN
          cli_cmd.version = nil
          report_unknown = true
        else
          report_unknown = false
        end

        if cli_cmd.version
          vers = Xolo::Admin::Version.fetch cli_cmd.title, cli_cmd.version, server_cnx
          data = vers.patch_report_data(server_cnx)
          rpt_title = "Patch Report for Version '#{cli_cmd.version}' of Title '#{cli_cmd.title}'"
          all_versions = false
        else
          title = Xolo::Admin::Title.fetch cli_cmd.title, server_cnx
          data = title.patch_report_data(server_cnx)
          data.select! { |d| d[:version] == Xolo::UNKNOWN } if report_unknown
          rpt_title = "Patch Report for Title '#{cli_cmd.title}'"
          all_versions = true
        end

        if data.empty?

          puts "# #{rpt_title}"
          puts '# No Data Found'

          return
        end

        if cli_cmd_opts.summary
          display_patch_report_summary(data, rpt_title)
          return
        end

        if json?
          puts JSON.pretty_generate(data)
          return
        end

        # NOTE: The order of things in this array must match
        # that in each array of the data, below
        header_row = %w[Computer User]
        header_row << 'Version' if all_versions
        header_row << 'LastContact'

        header_row << 'OS' if cli_cmd_opts.os
        header_row << 'Dept' if cli_cmd_opts.dept
        header_row << 'Building' if cli_cmd_opts.building
        header_row << 'Site' if cli_cmd_opts.site
        header_row << 'Frozen' if cli_cmd_opts.frozen
        header_row << 'JamfID' if cli_cmd_opts.id

        # See note above about the order of items in each sub-array
        data = data.map do |d|
          last_contact = Time.parse(d[:lastContactTime]).localtime.strftime('%F %T')
          comp_ary = [d[:computerName], d[:username]]
          comp_ary << d[:version] if all_versions
          comp_ary << last_contact

          comp_ary << d[:operatingSystemVersion] if cli_cmd_opts.os
          comp_ary << d[:departmentName] if cli_cmd_opts.dept
          comp_ary << d[:buildingName] if cli_cmd_opts.building
          comp_ary << d[:siteName] if cli_cmd_opts.site
          comp_ary << d[:frozen] if cli_cmd_opts.frozen
          comp_ary << d[:deviceId] if cli_cmd_opts.id
          comp_ary
        end

        show_text generate_report(data, header_row: header_row, title: rpt_title)
      rescue StandardError => e
        handle_processing_error e
      end

      # Show a summary of the patch report data
      #
      # @param data [Array<Hash>] the patch report data
      # @return [void]
      ###############################
      def display_patch_report_summary(data, rpt_title)
        version_counts = {}
        unknown = 0
        data.each do |d|
          if d[:version] == Xolo::UNKNOWN || d[:version].pix_empty?
            unknown += 1
            next
          end

          vers = Gem::Version.new(d[:version])
          version_counts[vers] ||= 0
          version_counts[vers] += 1
        end

        header_row = ['Version', 'Number of Installs']
        title = "Summary #{rpt_title}"

        summary_data = []
        summary_data << ['All Versions', data.size] unless rpt_title.include? 'Version'

        version_counts.keys.sort.reverse.each do |vers|
          summary_data << [vers, version_counts[vers]]
        end
        summary_data << ['Unknown', unknown] if unknown.positive? && !rpt_title.include?('Version')

        if json?
          puts JSON.pretty_generate(summary_data.to_h)
          return
        end

        show_text generate_report(summary_data, header_row: header_row, title: title)
      end

      # Show info about the server status
      #
      # @return [void]
      ###############################
      def server_status
        route = cli_cmd_opts.extended ? "#{SERVER_STATUS_ROUTE}?extended=true" : SERVER_STATUS_ROUTE

        data = server_cnx.get(route).body

        if json?
          puts JSON.pretty_generate(data)
          return
        end

        require 'pp'

        header = +'# Xolo Server Status'
        header << ' (extended)' if cli_cmd_opts.extended
        puts header
        puts '##################################################'
        pp data
        nil
      rescue StandardError => e
        handle_processing_error e
      end

      # kick off server cleanup
      #
      # @return [void]
      ###############################
      def server_cleanup
        return unless confirmed? 'Run the Xolo Server cleanup process'

        result = server_cnx.post(SERVER_CLENUP_ROUTE).body
        puts result[:result]
      rescue StandardError => e
        handle_processing_error e
      end

      # force update the client data pkg
      #
      # @return [void]
      ###############################
      def update_client_data
        return unless confirmed? 'Force update of the client data package'

        result = server_cnx.post(SERVER_UPDATE_CLIENT_DATA_ROUTE).body
        puts result[:result]
      rescue StandardError => e
        handle_processing_error e
      end

      # rotate the server logs
      #
      # @return [void]
      ###############################
      def rotate_server_logs
        return unless confirmed? 'Rotate the Xolo Server logs'

        result = server_cnx.post(SERVER_ROTATE_LOGS_ROUTE).body
        puts result[:result]
      rescue StandardError => e
        handle_processing_error e
      end

      # set the server log level
      #
      # @return [void]
      ###############################
      def set_server_log_level
        level = ARGV.shift&.downcase
        raise ArgumentError, 'No log level given' unless level

        unless LOG_LEVELS.include? level
          raise ArgumentError, "Invalid log level '#{level}', must be one of #{LOG_LEVELS.join(', ')}"
        end

        return unless confirmed? "Set the Xolo Server log level to '#{level}'?"

        payload = { level: level }
        result = server_cnx.post(SERVER_LOG_LEVEL_ROUTE, payload).body
        puts result[:result]
      rescue StandardError => e
        handle_processing_error e
      end

      # shutdown the server
      #
      # @return [void]
      ###############################
      def shutdown_server
        return unless confirmed? 'Shutdown the Xolo Server'

        restart = cli_cmd_opts.restart
        action = restart ? 'Restart' : 'Shutdown'
        payload = { restart: restart }

        result = server_cnx.post(SERVER_SHUTDOWN_ROUTE, payload).body
        puts "result[:result] = #{result[:result]}"

        if debug?
          puts "DEBUG: response_data: #{result}"
          puts
        end

        display_progress result[:progress_stream_url_path]

        puts "#{action} complete"
      rescue Faraday::ConnectionFailed
        puts "#{action} complete"
      rescue StandardError => e
        puts "Error Class: #{e.class}"
        handle_processing_error e
      end

      # List all the computer groups in jamf pro
      #
      # @return [void]
      ############################
      def list_groups
        if json?
          puts JSON.pretty_generate(jamf_computer_group_names)
          return
        end
        header = "Computer Groups in Jamf Pro.\n# Those starting with 'xolo-' are used internally by Xolo and not shown."
        list_in_cols header, jamf_computer_group_names.sort_by(&:downcase)
      end

      # List all the SSVC categories in jamf pro
      #
      # @return [void]
      ############################
      def list_categories
        if json?
          puts JSON.pretty_generate(jamf_category_names)
          return
        end

        list_in_cols 'Categories in Jamf Pro:', jamf_category_names.sort_by(&:downcase)
      end

      # run the cleanup
      # get the /test route to do whatever testing it does
      # during testing - this will return all kinds of things.
      #
      # @return [void]
      ##########################
      def run_test_route
        cli_cmd.command = 'test'
        if ARGV.include? '--quiet'
          global_opts.quiet = true
          puts "Set global_opts.quiet = true : #{global_opts.quiet}"
        end

        login test: true
        resp = server_cnx.get('/default_min_os').body.first.to_s
        puts "RESPONSE:\n#{resp}"
        return unless resp[:progress_stream_url_path]

        puts
        if global_opts.quiet
          puts 'given --quiet, not showing progress'
        else
          puts 'Streaming progress:'
          display_progress resp[:progress_stream_url_path]
        end

        # test uploads
        # 1.2 gb
        large_file = '/dist/caspershare/Packages-DEACTIVATED/SecUpd2020-006HighSierra.pkg'

        pkg_to_upload = Pathname.new large_file
        puts "Uploading Test File #{pkg_to_upload.size} bytes... "
        upload_test_file(pkg_to_upload)

        puts 'All Done!'
      rescue StandardError => e
        msg = e.respond_to?(:response_body) ? "#{e}\nRespBody: #{e.response_body}" : e.to_s
        puts "TEST ERROR: #{e.class}: #{msg}"
        puts e.backtrace
      end

      # Upload a file to the test upload route
      #
      # @param pkg_to_upload [Pathname] a local file to upload
      #
      # @return [void]
      #
      ############################
      def upload_test_file(pkg_to_upload)
        route = '/upload/test'

        upfile = Faraday::UploadIO.new(
          pkg_to_upload.to_s,
          'application/octet-stream',
          pkg_to_upload.basename.to_s
        )

        content = { file: upfile }
        # upload the file in a thread
        Thread.new { upload_cnx.post(route) { |req| req.body = content } }

        # when the server starts the upload, it notes the new
        # streaming url for our session[:xolo_id], which we can then fetch and
        # start displaying the progress
        display_progress response_data[:progress_stream_url_path]
      end

      # get confirmation for an action that requires it
      # @param action [String] A short description of what we're about to do,
      #   e.g. "Add version '1.2.3' to title 'cool-app'"
      #
      # @return [Boolean] did we get confirmation?
      ############################
      def confirmed?(action)
        return true unless need_confirmation?

        puts "About to: #{action}"
        print 'Are you sure? (y/n): '
        STDIN.gets.chomp.downcase.start_with? 'y'
      end

      # Start displaying the progress of a long-running task on the server
      # but only if we aren't --quiet
      # @return [void]
      ##################################
      def display_progress(url_path)
        # in case it's nil
        return unless url_path

        # always make note of the path in the history
        add_progress_history_entry url_path
        return if quiet?

        # if any line of the contains 'ERROR' we can skip
        # any post-stream processing.
        @streaming_error = false

        streaming_cnx.get url_path

        raise Xolo::ServerError, 'There was an error while streaming the server progress.' if @streaming_error
      end

      # Handle errors while processing xadm commands
      #
      #######################
      def handle_processing_error(err)
        # puts "Err: #{err.class} #{err}"
        case err
        when Faraday::Error
          begin
            jsonerr = parse_json err.response_body
            errmsg = "#{jsonerr[:error]} [#{err.response_status}]"

          # if we got a faraday error, but it didn't contain
          # JSON, return just the error body, or the error itself
          rescue StandardError
            msg = err.response_body if err.respond_to?(:response_body)
            msg ||= err.to_s
            errmsg = "#{err.class.name.split('::').last}: #{msg}"
          end # begin
          raise err.class, errmsg

        else
          raise err
        end # case
      end

      # Just output lots of local things, for testing
      #
      # Comment/uncomment as needed
      #
      ########################
      def do_local_testing
        puts '-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+'
        puts Xolo::Admin::Title.release_to_all_allowed?(server_cnx)

        ###################
        # puts
        # puts '-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+'
        # puts 'GLOBAL OPTS:'
        # puts '----'
        # global_opts.to_h.each do |k, v|
        #   puts "..#{k} => #{v}"
        # end

        ###################
        # puts
        # puts "COMMAND: #{cli_cmd.command}"

        ###################
        # puts
        # puts "TITLE: #{cli_cmd.title}"

        ###################
        # puts
        # puts "VERSION: #{cli_cmd.version}"

        ###################
        # puts
        # puts 'CURRENT OPT VALUES:'
        # puts 'The values the object had before xadm started working on it.'
        # puts 'If the object is being added, these are the default or inherited values'
        # puts '----'
        # current_opt_values.to_h.each do |k, v|
        #   puts "..#{k} => #{v}"
        # end

        ###################
        # puts
        # puts 'COMMAND OPT VALUES:'
        # puts 'The command options collected by xadm, merged with the'
        # puts 'current values, to be applied to the object'
        # puts '----'
        # opts = walkthru? ? walkthru_cmd_opts : cli_cmd_opts
        # opts.to_h.each do |k, v|
        #   puts "..#{k} => #{v}"
        # end

        ###################
        # puts 'CookieJar:'
        # puts "  Session: #{Xolo::Admin::CookieJar.session_cookie}"
        # puts "  Expires: #{Xolo::Admin::CookieJar.session_expires}"

        ###################
        # puts 'getting /state'
        # resp = server_cnx.get '/state'
        # puts "#{resp.body}"

        # ###################
        # puts 'Listing currently known titles:'
        # all_titles = Xolo::Admin::Title.all_titles server_cnx
        # puts all_titles

        # # ###############
        # already_there = all_titles.include? cli_cmd.title
        # puts "all titles contains our title: #{already_there}"
        # if already_there
        #   puts 'deleting the title first'
        #   resp = Xolo::Admin::Title.delete cli_cmd.title, server_cnx
        #   puts "Delete Status: #{resp.status}"
        #   puts 'Delete Body:'
        #   puts resp.body
        # end

        # # ###################
        # process_method = Xolo::Admin::Options::COMMANDS[cli_cmd.command][:process_method]
        # puts
        # puts "Processing command opts using method: #{process_method}"
        # resp = send process_method if process_method
        # puts "Add Status: #{resp.status}"
        # puts 'Add Body:'
        # puts resp.body
        # puts

        # ##################
        # puts 're-fetching...'
        # title = Xolo::Admin::Title.fetch cli_cmd.title, server_cnx
        # puts "title class: #{title.class}"
        # puts 'title to_h:'
        # puts title.to_h
        # puts

        # ##################
        # puts 'updating...'
        # title.self_service = false
        # resp = title.update server_cnx
        # puts "Update Status: #{resp.status}"
        # puts 'Update Body:'
        # puts resp.body
        # puts

        ###################
        # puts 'running jamf_package_names'
        # puts jamf_package_names

        ###################
        # puts 'running ted_titles'
        # puts ted_titles

        ##################
        # puts
        # puts 'DONE'
      end # do_local_testing

    end # module processing

  end # module Admin

end # module Xolo
