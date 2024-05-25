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

    # Methods that execute the xadm commands and their options
    #
    module Processing

      # Constants
      ##########################
      ##########################

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

      # update the adm config file using the values from 'xadm config'
      #
      # @return [void]
      ###############################
      def update_config
        Xolo::Admin::Configuration::KEYS.each_key do |key|
          config.send "#{key}=", opts_to_process[key]
        end

        config.save_to_file
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

        report_title = 'All titles in Xolo'
        header = %w[Title Created By SSvc? Curr Latest]
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
        show_text generate_report(data, header_row: header, title: report_title)
      rescue StandardError => e
        handle_server_error e
      end

      # Add a title to Xolo
      #
      # @return [void]
      ###############################
      def add_title
        return unless confirmed? "Add title '#{cli_cmd.title}'"

        opts_to_process.title = cli_cmd.title

        new_title = Xolo::Admin::Title.new opts_to_process
        response_data = new_title.add(server_cnx)

        if debug?
          puts "response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]

        # Upload the ssvc icon, if any?
        upload_ssvc_icon new_title

        speak "Title '#{cli_cmd.title}' has been added to Xolo.\nAdd at least one version to enable piloting and deployment"
      rescue StandardError => e
        handle_server_error e
      end

      # Edit/Update a title in Xolo
      #
      # @return [void]
      ###############################
      def edit_title
        return unless confirmed? "Edit title '#{cli_cmd.title}'"

        opts_to_process.title = cli_cmd.title

        title = Xolo::Admin::Title.new opts_to_process
        response_data = title.update server_cnx

        if debug?
          puts "response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]

        # Upload the ssvc icon, if any?
        upload_ssvc_icon title

        speak "Title '#{cli_cmd.title}' has been updated in Xolo."
      rescue StandardError => e
        handle_server_error e
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

        # upload_thr = Thread.new { title.upload_self_service_icon(upload_cnx) }

        # # check the thread every second, but only update the terminal every 10 secs
        # count = 0
        # while upload_thr.alive?

        #   speak "... #{Time.now.strftime '%F %T'} Upload in progress" if (count % 10).zero?
        #   sleep 1
        #   count += 1
        # end

        speak 'Self-service icon uploaded. Will be added to Self Service policies as needed'
      rescue StandardError => e
        handle_server_error e
      end

      # Delete a title in Xolo
      #
      # @return [void]
      ###############################
      def delete_title
        return unless confirmed? "Delete title '#{cli_cmd.title}' and all its versions"

        response_data = Xolo::Admin::Title.delete cli_cmd.title, server_cnx

        if debug?
          puts "response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]

        speak "Title '#{cli_cmd.title}' has been deleted from Xolo."
      rescue StandardError => e
        handle_server_error e
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

        report_title = "All versions of '#{cli_cmd.title}' in Xolo"
        header = %w[Vers Created By Released By Status]
        data = versions.map do |v|
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
        handle_server_error e
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
          puts "response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]

        # Upload the pkg, if any?
        upload_pkg(new_vers)
      rescue StandardError => e
        handle_server_error e
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
      end

      # Edit/Update a version in Xolo
      #
      # @return [void]
      ###############################
      def edit_version
        # TODO: confirmation before editing
        opts_to_process.title = cli_cmd.title
        opts_to_process.version = cli_cmd.version
        vers = Xolo::Admin::Version.new opts_to_process

        vers.update server_cnx

        # Upload the pkg, if any?
        vers.upload_pkg(upload_cnx) if vers.pkg_to_upload.is_a? Pathname

        speak "Version '#{cli_cmd.version}' of title '#{cli_cmd.title}' has been updated in Xolo."
      rescue StandardError => e
        handle_server_error e
      end

      # Delete a title in Xolo
      #
      # @return [void]
      ###############################
      def delete_version
        return unless confirmed? "Delete version '#{cli_cmd.version}' from title '#{cli_cmd.title}'"

        response_data = Xolo::Admin::Version.delete cli_cmd.title, cli_cmd.version, server_cnx

        if debug?
          puts "response_data: #{response_data}"
          puts
        end

        display_progress response_data[:progress_stream_url_path]
      rescue StandardError => e
        handle_server_error e
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

        puts "# Info for Title '#{cli_cmd.title}'"
        puts '###################################'

        Xolo::Admin::Title::ATTRIBUTES.each do |attr, deets|
          next if deets[:hide_from_info]

          value = title.send attr
          value = value.join(Xolo::COMMA_JOIN) if value.is_a? Array
          puts "- #{deets[:label]}: #{value}".pix_word_wrap
        end
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

        puts "# Info for Version #{cli_cmd.version} of Title '#{cli_cmd.title}'"
        puts '##################################################'

        Xolo::Admin::Version::ATTRIBUTES.each do |attr, deets|
          next if deets[:hide_from_info]

          value = vers.send attr
          value = value.join(Xolo::COMMA_JOIN) if value.is_a? Array
          puts "- #{deets[:label]}: #{value}".pix_word_wrap
        end
      rescue Faraday::ResourceNotFound
        puts "No Such Version '#{cli_cmd.version}' of Title '#{cli_cmd.title}'"
      end

      # Show info about the server status
      #
      # @return [void]
      def server_status
        require 'pp'

        puts '# Xolo Server Status'
        puts '##################################################'
        data = server_cnx.get('/state').body
        pp data
      end

      # List all the computer groups in jamf pro
      #
      # @return [void]
      ############################
      def list_groups
        list_in_cols 'All Computer Groups in Jamf Pro:', jamf_computer_group_names.sort_by(&:downcase)
      end

      # List all the SSVC categories in jamf pro
      #
      # @return [void]
      ############################
      def list_categories
        list_in_cols 'All Categories in Jamf Pro:', jamf_category_names.sort_by(&:downcase)
      end

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
        resp = server_cnx.get('/test').body
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
        thr = Thread.new { upload_cnx.post(route) { |req| req.body = content } }

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

        streaming_cnx.get url_path
      end

    end # module processing

  end # module Admin

end # module Xolo
