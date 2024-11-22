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

# frozen_string_literal: true

module Xolo

  module Admin

    # A collection of methods to convert and validate values used in Xolo.
    #
    # These methods will convert target values if possible, e.g. if a value
    # should be an Integer, a String containing an integer will be converted
    # before validation.
    #
    # If the converted value is valid, it will be returned, otherwise a
    # Xolo::InvalidDataError will be raised.
    #
    module Validate

      # Constants
      #########################
      #########################

      # True can be specified as 'true' or 'y' or 'yes'
      # case insensitively. Anything else is false.
      TRUE_RE = /(\Atrue\z)|(\Ay(es)?\z)/i.freeze

      # Convenience - constants from classes

      TITLE_ATTRS = Xolo::Admin::Title::ATTRIBUTES
      VERSION_ATTRS = Xolo::Admin::Version::ATTRIBUTES

      # Self Service icons must be one of these mime types,
      # as determined by the output of `file -b -I`
      SSVC_ICON_MIME_TYPES = %w[
        image/jpeg
        image/png
        image/gif
      ]

      # Module methods
      ##############################
      ##############################

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # Instance Methods
      ##########################
      ##########################

      # Thes methods all raise this error
      def raise_invalid_data_error(val, msg)
        raise Xolo::InvalidDataError, "'#{val}': #{msg}"
      end

      # is the given command valid?
      #########
      def validate_cli_command
        return if Xolo::Admin::Options::COMMANDS.key? cli_cmd.command

        msg = cli_cmd.command.pix_empty? ? "Usage: #{usage}" : "Unknown command: '#{cli_cmd.command}'"
        raise ArgumentError, msg
      end # validate command

      # were we given a title?
      #########
      def validate_cli_title
        # this command doesn't need a title arg
        return if Xolo::Admin::Options::COMMANDS[cli_cmd.command][:target] == :none

        raise ArgumentError, "No title provided!\nUsage: #{usage}" unless cli_cmd.title

        # this validates the format
        validate_title cli_cmd.title
      end

      # were we given a version?
      #########
      def validate_cli_version
        # this command doesn't need a version arg
        return unless version_command? || title_or_version_command?

        # TODO:
        #   If this is an 'add-' command, ensure the version
        #   doesn't already exist.
        #   Otherwise, make sure it does already exist
        #

        vers = cli_cmd.version
        return unless vers.to_s.empty? || vers.start_with?(Xolo::DASH)

        raise ArgumentError, "No version provided with '#{cli_cmd.command}' command!\nUsage: #{usage}"
      end

      # Validate the command options acquired from the command line.
      # Walkthru will validate them individually as they are entered.
      #
      ##########################
      def validate_cli_cmd_opts
        cmd = cli_cmd.command
        opts_defs = Xolo::Admin::Options::COMMANDS[cmd][:opts]
        return if opts_defs.empty?

        opts_defs.each do |key, deets|
          # skip things not given on the command line
          next unless cli_cmd_opts["#{key}_given"]

          # skip things that shouldn't be validated
          next unless deets[:validate]

          # if the item is not required, and 'none' is given, set the
          # value to nil and we're done
          unless deets[:required]
            if cli_cmd_opts[key].is_a?(Array) && cli_cmd_opts[key].include?(Xolo::NONE)
              cli_cmd_opts[key] = []
              next
            elsif cli_cmd_opts[key] == Xolo::NONE
              cli_cmd_opts[key] = nil
              next
            end
          end

          # If an item is :multi, it is an array.
          # If it has only one item, split it on commas
          # This handles multi items being given multiple times as CLI opts, or
          # as comma-sep values in CLI opts or walkthru.
          #
          if deets[:multi] && cli_cmd_opts[key].size == 1
            cli_cmd_opts[key] = cli_cmd_opts[key].first.split(Xolo::COMMA_SEP_RE)
          end

          validation_method =
            case deets[:validate]
            when Symbol
              deets[:validate]
            when TrueClass
              "validate_#{key}"
            end

          # nothing to do if no validation method
          next unless validation_method

          # run the validation, which raises an error if invalid, or returns
          # the converted value if OK - the converted value replaces the original in the
          # cmd_opts
          cli_cmd_opts[key] = send validation_method, cli_cmd_opts[key]
        end

        # if we are here, eveything on the commandline checked out, so now
        # go through the opts_defs keys, and for any that were not given on the command line,
        # add the value for that key from current_opt_values to Xolo::Admin::Options.cli_cmd_opts
        # which will then be passed for internal consistency validation.
      end

      # Title Attributes
      #
      ##################################################

      # validate a Xolo title. Must be 2+ chars long, only lowercase
      # alpha-numerics & dashes
      #
      # Must also exist or not exist, depending on the command we are running
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      ##########################
      def validate_title(val)
        val = val.to_s.strip

        title_exists = Xolo::Admin::Title.exist?(val, server_cnx)

        # adding... cant already exist, and name must be OK
        if cli_cmd.command == Xolo::Admin::Options::ADD_TITLE_CMD
          err =
            if title_exists
              'already exists in Xolo'
            elsif val !~ /\A[a-z0-9-][a-z0-9-]+\z/
              TITLE_ATTRS[:title][:invalid_msg]
            else
              return val
            end

        # a command where it must exist
        elsif Xolo::Admin::Options::MUST_EXIST_COMMANDS.include?(cli_cmd.command)
          return val if title_exists

          err = "doesn't exist in Xolo"

        # any other command
        else
          return val
        end

        raise_invalid_data_error val, err
      end

      # validate a title display-name. Must be 3+ chars long
      #
      # @param val [Object] The value to validate
      #
      #
      # @return [String] The valid value
      ##########################
      def validate_title_display_name(val)
        val = val.to_s.strip
        return val if val =~ /\A\S.+\S\z/

        raise_invalid_data_error val, TITLE_ATTRS[:display_name][:invalid_msg]
      end

      # validate a title description. Must be 20+ chars long
      #
      # @param val [Object] The value to validate
      #
      # @return [Boolean, String] The validity, or the valid value
      ##########################
      def validate_title_desc(val)
        val = val.to_s.strip
        return val if val.length >= 20

        raise_invalid_data_error val, TITLE_ATTRS[:description][:invalid_msg]
      end

      # validate a title publisher. Must be 3+ chars long
      #
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      ##########################
      def validate_publisher(val)
        val = val.to_s.strip
        return val if val.length >= 3

        raise_invalid_data_error val, TITLE_ATTRS[:publisher][:invalid_msg]
      end

      # validate a title app_name. Must end with .app
      #
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      ##########################
      def validate_app_name(val)
        val = val.to_s.strip
        return val if val.end_with? Xolo::DOTAPP

        raise_invalid_data_error val, TITLE_ATTRS[:app_bundle_id][:invalid_msg]
      end

      # validate a title app_bundle_id. Must include at least one dot
      #
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      ##########################
      def validate_app_bundle_id(val)
        val = val.to_s.strip
        return val if val.include? Xolo::DOT

        raise_invalid_data_error val, TITLE_ATTRS[:app_bundle_id][:invalid_msg]
      end

      # validate a title version script. Must start with '#!'
      #
      # @param val [Object] The value to validate
      #
      # @return [Pathname] The valid value
      ##########################
      def validate_version_script(val)
        val = Pathname.new val.to_s.strip
        return val if val.file? && val.readable? && val.read.start_with?('#!')

        raise_invalid_data_error val, TITLE_ATTRS[:version_script][:invalid_msg]
      end

      # validate a title uninstall script:
      # - a path to a script which must start with '#!'
      # OR
      # - 'none' to unset the value
      #
      # TODO: Consistency with expiration.
      #
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      ##########################
      def validate_uninstall_script(val)
        val = val.to_s.strip
        return if val == Xolo::NONE

        script_file = Pathname.new(val).expand_path

        if script_file.readable?
          script = script_file.read
          return script_file.to_s if script.start_with? '#!'
        end

        raise_invalid_data_error val, TITLE_ATTRS[:uninstall_script][:invalid_msg]
      end

      # validate a title uninstall ids:
      # - an array of package identifiers
      # OR
      # - 'none' to unset the value
      #
      # TODO: Consistency with expiration.
      #
      # @param val [Object] The value to validate
      #
      # @return [Array<String>] The valid value
      ##########################
      def validate_uninstall_ids(val)
        val = [val] unless val.is_a? Array
        return Xolo::X if val == [Xolo::X]
        return [] if val.include? Xolo::NONE

        return val

        raise_invalid_data_error val, TITLE_ATTRS[:uninstall_ids][:invalid_msg]
      end

      # validate an array of jamf group names to use as targets when released.
      # 'all', or 'none' are also acceptable
      #
      # These groups cannot be in the excluded_group - but that validation happens
      # later in the consistency checks via validate_scope_targets_and_exclusions
      #
      # @param val [Array<String>] The value to validate:  names of jamf comp.
      #   groups, or 'all', or 'none'
      #
      # @return [Array<String>] The valid value
      ##########################
      def validate_release_groups(val)
        val = [val] unless val.is_a? Array
        if  val.include? Xolo::NONE
          return []
        elsif val.include? Xolo::TARGET_ALL
          validate_release_to_all_allowed

          return [Xolo::TARGET_ALL]
        end

        # non-existant jamf groups
        bad_grps = bad_jamf_groups(val)
        return val if bad_grps.empty?

        bad_grps = "No Such Groups: #{bad_grps.join(Xolo::COMMA_JOIN)}"
        raise_invalid_data_error bad_grps, TITLE_ATTRS[:release_groups][:invalid_msg]
      end

      # check if the current admin is allowed to set a title's release groups to 'all'
      #
      # @return [void]
      ##########################
      def validate_release_to_all_allowed
        svr_resp = Xolo::Admin::Title.release_to_all_allowed?(server_cnx)
        return if svr_resp[:allowed]

        raise Xolo::InvalidDataError, svr_resp[:msg]
      end

      # validate an array  of jamf groups to use as exclusions.
      # 'none' is also acceptable
      #
      # excluded groups cannot be in the release groups or pilot groups
      #
      # @param val [Array<String>] The value to validate:  names of jamf comp.
      #   groups, or 'none'
      #
      # @return [Array<String>] The valid value
      ##########################
      def validate_excluded_groups(val)
        val = [val] unless val.is_a? Array
        return [] if val.include? Xolo::NONE

        bad_grps = bad_jamf_groups(val)
        return val if bad_grps.empty?

        bad_grps = "No Such Groups: #{bad_grps.join(Xolo::COMMA_JOIN)}"

        raise_invalid_data_error bad_grps, TITLE_ATTRS[:excluded_groups][:invalid_msg]
      end

      # @param grp_ary [Array<String>] Jamf groups to validate
      # @return [Array<String>] Jamf groups that do not exist.
      ##########################
      def bad_jamf_groups(group_ary)
        group_ary = [group_ary] unless group_ary.is_a? Array

        group_ary - jamf_computer_group_names
      end

      # validate a titles expiration. Must be a non-negative integer
      #
      # @param val [Object] The value to validate
      #
      # @return [Integer] The valid value
      ##########################
      def validate_expiration(val)
        val = val.to_s
        if val.pix_integer?
          val = val.to_i
          return Xolo::NONE if val.zero?
          return val if val.positive?
        elsif val == Xolo::NONE
          return val
        end

        raise_invalid_data_error val, TITLE_ATTRS[:expiration][:invalid_msg]
      end

      # validate a title expiration paths. Must one or more full paths
      # starting with a / and containing at least one more.
      #
      # @param val [Object] The value to validate
      #
      # @return [Array<String>] The valid array
      ##########################
      def validate_expire_paths(val)
        val = [val] unless val.is_a? Array
        return [] if val.include? Xolo::NONE

        val.map!(&:to_s)
        bad_paths = []

        val.each { |path| bad_paths << path unless path =~ %r{\A/\w.*/.*\z} }

        return val if bad_paths.empty?

        raise_invalid_data_error bad_paths.join(Xolo::COMMA_JOIN), TITLE_ATTRS[:expire_paths][:invalid_msg]
      end

      # validate boolean options
      #
      # Never raises an error, just returns true of false based on the string value
      #
      # @param val [Object] The value to validate
      #
      # @return [Boolean] The  valid value
      ##########################
      def validate_boolean(val)
        val.to_s =~ TRUE_RE ? true : false
      end

      # validate a self_service_category. Must exist in Jamf Pro
      #
      # @param val [Object] The value to validate
      #
      # @return [Boolean, String] The validity, or the valid value
      ##########################
      def validate_self_service_category(val)
        val = val.to_s

        # TODO: implement the check via the xolo server
        return val # if category exists

        raise_invalid_data_error val, TITLE_ATTRS[:self_service_category][:invalid_msg]
      end

      # validate a path to a self_service_icon. Must exist locally and be readable
      #
      # @param val [Object] The value to validate
      #
      # @return [Pathname] The valid value
      ##########################
      def validate_self_service_icon(val)
        val = Pathname.new val.to_s.strip
        if val.file? && val.readable?
          mimetype = `/usr/bin/file -b -I #{Shellwords.escape val.to_s}`.split(';').first
          return val if SSVC_ICON_MIME_TYPES.include? mimetype
        end

        raise_invalid_data_error val, TITLE_ATTRS[:self_service_icon][:invalid_msg]
      end

      # validate a path to a jamf_pkg_file. Must exist locally and be readable
      # and have the correct ext.
      #
      # @param val [Object] The value to validate
      #
      # @return [Pathname] The valid value
      ##########################
      def validate_pkg_to_upload(val)
        val = Pathname.new val.to_s.strip
        return val if val.file? && val.readable? && (Xolo::OK_PKG_EXTS.include? val.extname)

        raise_invalid_data_error val, VERSION_ATTRS[:jamf_pkg_file][:invalid_msg]
      end

      # Version Attributes
      #
      ##################################################

      # TODO: validate a Xolo Version. Must be 2+ chars long, only lowercase
      # alpha-numerics & dashes
      #
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      ##########################
      def validate_version(val)
        val
      end

      # @param val [Object] The value to validate
      #
      # @return [Date] The valid value
      ##########################
      def validate_publish_date(val)
        val = Time.now.to_s if val.pix_empty?
        val = Time.parse val.to_s
        # TODO: ? Ensure this date is >= the prev. version and <= the next
        return val if true

        raise VERSION_ATTRS[:publish_date][:invalid_msg]
      rescue StandardError => e
        raise_invalid_data_error val, e.to_s
      end

      # @param val [Object] The value to validate
      #
      # @return [Gem::Version] The valid value
      ##########################
      def validate_min_os(val)
        # inherit if needed
        val = current_opt_values[:min_os] if val == Xolo::NONE || val.pix_empty?

        return val.to_s unless val.pix_empty?

        raise VERSION_ATTRS[:min_os][:invalid_msg]
      rescue StandardError => e
        raise_invalid_data_error val, e.to_s
      end

      # @param val [Object] The value to validate
      #
      # @return [Gem::Version] The valid value
      ##########################
      def validate_max_os(val)
        return val if true

        raise VERSION_ATTRS[:max_os][:invalid_msg]
      rescue StandardError => e
        raise_invalid_data_error val, e.to_s
      end

      # @param val [Object] The value to validate
      #
      # @return [Array<Array<String>>] The valid value
      ##########################
      def validate_killapps(val)
        val = [val] unless val.is_a? Array
        return Xolo::X if val == [Xolo::X]
        return Xolo::NONE if val.include? Xolo::NONE

        val.map!(&:to_s)

        # if one of the killapps is Xolo::Admin::Version::USE_TITLE_FOR_KILLAPP
        # convert it into the appropriate string
        val.map! { |ka| expand_use_title(ka) }

        val.each { |ka| validate_single_killapp(ka) }

        val
      end

      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      ##########################
      def validate_contact_email(val)
        val = val.to_s.strip
        return val if val =~ /\A\S+@\S+\.\S+\z/

        raise_invalid_data_error val, VERSION_ATTRS[:contact_email][:invalid_msg]
      end

      # expand Xolo::Admin::Version::USE_TITLE_FOR_KILLAPP into the proper killall string
      #
      # @param ka [String] the string to expand if needed
      # @return [String] the original string, or the expanded version
      ##########################
      def expand_use_title(ka)
        return ka unless ka == Xolo::Admin::Version::USE_TITLE_FOR_KILLAPP

        title = Xolo::Admin::Title.fetch cli_cmd.title, server_cnx
        unless title.app_name
          raise_invalid_data_error Xolo::Admin::Version::USE_TITLE_FOR_KILLAPP,
                                   'Title does not use app_name'
        end
        unless title.app_bundle_id
          raise_invalid_data_error Xolo::Admin::Version::USE_TITLE_FOR_KILLAPP,
                                   'Title does not use app_bundle_id'
        end

        "#{title.app_name};#{title.app_bundle_id}"
      end

      # Validate an individual killapp string
      # @param ka [String] the string to expand if needed
      # @return [String] the validated value
      ##########################
      def validate_single_killapp(ka)
        name, bundle_id = ka.split(Xolo::SEMICOLON_SEP_RE)
        raise_invalid_data_error name, 'App name required before semicolon' unless name
        raise_invalid_data_error name, 'App Bundle ID required after semicolon' unless bundle_id

        # app name must end with .app. Use the err messge from Title/app_name
        raise_invalid_data_error name, TITLE_ATTRS[:app_name][:invalid_msg] unless name.end_with?(Xolo::DOTAPP)

        # app bundle id  must contain a dot. Use the err messge from Title/app_bundle_id
        unless bundle_id&.include?(Xolo::DOT)
          raise_invalid_data_error bundle_id,
                                   TITLE_ATTRS[:app_bundle_id][:invalid_msg]
        end

        ka
      end

      # validate an array  of jamf groups to use as pilots for testing a version
      # before releasing it.
      # 'none' is also acceptable
      #
      # NOTE: we will not compare targets to exclusions - we'll just verify
      # that the jamf groups exist. If a group (or an individual mac) is both a
      # pilot and an exclusion, the exclusion wins.
      #
      # @param val [Array<String>] The value to validate:  names of jamf comp.
      #   groups, or 'none'
      #
      # @return [Array<String>] The valid value
      ##########################
      def validate_pilot_groups(val)
        val = [val] unless val.is_a? Array
        return [] if val.include? Xolo::NONE

        bad_grps = bad_jamf_groups(val)
        return val if bad_grps.empty?

        bad_grps = "No Such Groups: #{bad_grps.join(Xolo::COMMA_JOIN)}"

        raise_invalid_data_error bad_grps, VERSION_ATTRS[:pilot_groups][:invalid_msg]
      end

      # Try to fetch a known route from the given xolo server
      #
      # @param val [String] The hostname to validate.
      #
      # @return [void]
      #######
      def validate_hostname(val)
        if val.downcase == 'x'
          val = nil
          return
        end

        response = server_cnx(host: val).get Xolo::Admin::Connection::PING_ROUTE
        return val if response.body == Xolo::Admin::Connection::PING_RESPONSE

        raise_invalid_data_error val, Xolo::Admin::Configuration::KEYS[:hostname][:invalid_msg]
      rescue Faraday::ConnectionFailed => e
        raise_invalid_data_error val, Xolo::Admin::Configuration::KEYS[:hostname][:invalid_msg]
      rescue Faraday::SSLError => e
        raise_invalid_data_error val, 'SSL Error. Be sure to use the fully qualified hostname.'
      end

      # Password (and username) will be validated via the server
      #
      # @param val [String] The passwd to be validated with the stored or given username
      #
      # @return [void]
      #######
      def validate_pw(val)
        if val.downcase == 'x'
          val = Xolo::BLANK
          return
        end

        hostname = walkthru? ? walkthru_cmd_opts[:hostname] : cli_cmd_opts[:hostname]
        admin = walkthru? ? walkthru_cmd_opts[:admin] : cli_cmd_opts[:admin]

        raise Xolo::MissingDataError, 'hostname must be set before password' if hostname.pix_empty?
        raise Xolo::MissingDataError, 'admin username must be set before password' if admin.pix_empty?

        payload = { admin: admin, password: val }.to_json
        resp = server_cnx(host: hostname).post Xolo::Admin::Connection::LOGIN_ROUTE, payload

        raise_invalid_data_error 'User/Password', resp.body[:error] unless resp.success?

        # store the passwd in the keychain
        store_pw admin, val

        # The passwd is never stored in the config, this is:
        Xolo::Admin::Configuration::CREDENTIALS_IN_KEYCHAIN
      end

      # Does the chosen editor exist and is it executable?
      #
      # @aram val [String] The path to the editor executable.
      #
      # @return [void]
      #######
      def validate_editor(val)
        val = Pathname.new val
        return val.to_s if val.executable?

        raise_invalid_data_error val, Xolo::Admin::Configuration::KEYS[:editor][:invalid_msg]
      end

      # Internal Consistency Checks!
      #
      ##################################################

      # These methods all raise this error
      #
      # @param msg [String] an error message
      #
      # @return [void]
      ########
      def raise_consistency_error(msg)
        raise Xolo::InvalidDataError, msg
      end

      # Given an ostruct of options that have been individually validated, and combined
      # with any current_opt_values as needed, check the data for internal consistency.
      # The unset values in the ostruct should be nil. 'none' is used for unsetting values,
      # in the CLI and walkthru, and is converted to nil during validation if appropriate.
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_internal_consistency(opts)
        return unless add_command? || edit_command?

        if version_command?
          validate_version_consistency opts
        elsif title_command?
          validate_title_consistency opts
        end
      end

      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_version_consistency(opts)
        validate_scope_targets_and_exclusions(opts)
        validate_min_os_and_max_os(opts)
      end

      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency(opts)
        # if we are just listing the versions, nothing to do
        return if cli_cmd.command == Xolo::Admin::Options::LIST_VERSIONS_CMD

        # order of these matters
        validate_scope_targets_and_exclusions(opts)
        validate_title_consistency_app_and_script(opts)
        validate_title_consistency_app_or_script(opts)
        validate_title_consistency_app_name_and_id(opts)
        validate_title_consistency_uninstall(opts)
        validate_title_consistency_expire_paths(opts)
        validate_title_consistency_no_all_in_ssvc(opts)
        validate_title_consistency_ssvc_needs_category(opts)
      end # title_consistency(opts)

      # groups that will be scope targets (pilot or release) cannot
      # also be in the exclusions.
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_scope_targets_and_exclusions(opts)
        # require 'pp'
        # puts 'Opts Are:'
        # pp opts.to_h
        # pp caller

        if title_command?
          excls = opts.excluded_groups
          tgts = opts.release_groups
          tgt_type = :release
        elsif version_command?
          @title_for_version_validation ||= Xolo::Admin::Title.fetch cli_cmd.title, server_cnx
          excls = @title_for_version_validation.excluded_groups
          tgts = opts.pilot_groups
          tgt_type = :pilot
        else
          excls = nil
          tgts = nil
        end
        return unless excls && tgts

        in_both = excls & tgts
        return if in_both.empty?

        raise_consistency_error "These groups are in both #{tgt_type}_groups and the title's excluded_groups: '#{in_both.join "', '"}'"
      end

      # if app_name or app_bundle_id is given, can't use --version-script
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency_app_and_script(opts)
        return unless opts[:version_script] && (opts[:app_bundle_id] || opts[:app_name])

        msg =
          if walkthru?
            'Version Script cannot be used with App Name & App Bundle ID'
          else
            '--version-script cannot be used with --app-name & --app-bundle-id'
          end

        raise_consistency_error msg
      end

      # but either version_script or appname and bundle id must be given
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency_app_or_script(opts)
        return if opts[:version_script]
        return if opts[:app_name] || opts[:app_bundle_id]

        msg =
          if walkthru?
            'Either App Name & App Bundle ID. or Version Script must be given.'
          else
            'Must provide either --app-name & --app-bundle-id OR --version-script'
          end
        raise_consistency_error msg
      end

      # If using app_name and bundle id, both must be given
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency_app_name_and_id(opts)
        return if opts[:version_script]
        return if opts[:app_name] && opts[:app_bundle_id]

        msg =
          if walkthru?
            'App Name & App Bundle ID must both be given if either is.'
          else
            '--app-name & --app-bundle-id must both be given if either is.'
          end
        raise_consistency_error msg
      end

      # if expiration is > 0, there must be at least one expiration path
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency_expire_paths(opts)
        return unless opts.expiration.to_i.positive?
        return unless opts.expire_paths.pix_empty?

        msg =
          if walkthru?
            'At least one Expiration Path must be given if Expiration is > 0.'
          else
            'At least one --expiration-path must be given if --expiration is > 0'
          end
        raise_consistency_error msg
      end

      # if uninstall script, cant have uninstall ids
      # and vice versa
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency_uninstall(opts)
        # walktrhu will have already validated this
        return if walkthru?

        if opts.uninstall_script_given && opts.uninstall_ids_given

          # if uninstall_script is given, uninstall_ids must be unset
          # and vice versa
          # raise an error if both are given

          raise_consistency_error '--uninstall-script cannot be used with --uninstall-ids'

        elsif opts.uninstall_script_given
          opts.uninstall_ids = nil

        elsif opts.uninstall_ids_given
          opts.uninstall_script_given = nil
        end
      end

      # if target_group is all, can't be in self service
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency_no_all_in_ssvc(opts)
        return unless opts[:release_groups].to_a.include?(Xolo::TARGET_ALL) && opts[:self_service]

        msg =
          if walkthru?
            "Cannot be in Self Service when Target Group is '#{Xolo::TARGET_ALL}'"
          else
            "--self-service cannot be used when --target-groups contains '#{Xolo::TARGET_ALL}'"
          end
        raise_consistency_error msg
      end

      # if in self service, a category must be assigned
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency_ssvc_needs_category(opts)
        return unless opts[:self_service]
        return if opts[:self_service_category]

        msg =
          if walkthru?
            'A Self Service Category must be given if Self Service is true.'
          else
            'A --self-service-category must be provided when using --self-service'
          end
        raise_consistency_error msg
      end

      # min_os must be <= max_os
      # max_os must be >= min_os
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_min_os_and_max_os(opts)
        # if no max_os, nothing to do
        return if opts[:max_os].pix_empty?

        min_os = Gem::Version.new opts[:min_os]
        max_os = Gem::Version.new opts[:max_os]

        # if things look OK, we're done
        return if min_os <= max_os && max_os >= min_os

        msg =
          if walkthru?
            'Minimum OS must be less than or equal to Maximum OS'
          else
            '--max-os must be greater than or equal to --min-os'
          end
        raise_consistency_error msg
      end

    end # module validate

  end # module Core

end # module Xolo
