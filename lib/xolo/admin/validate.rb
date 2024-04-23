# Copyright 2023 Pixar
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
        raise Xolo::InvalidDataError, "'#{val}' #{msg}"
      end

      # is the given command valid?
      #########
      def validate_cli_command
        cmd = cli_cmd.command
        return if Xolo::Admin::Options::COMMANDS.key? cmd

        msg =
          if cmd.to_s.empty?
            "Usage: #{usage}"
          else
            "Unknonwn command: #{cmd}"
          end
        raise ArgumentError, msg
      end # validate command

      # were we given a title?
      #########
      def validate_cli_title
        # this command doesn't need a title arg
        return if Xolo::Admin::Options::COMMANDS[cli_cmd.command][:target] == :none

        # TODO:
        #   If this is an 'add-' command, ensure the title
        #   doesn't already exist.
        #   Otherwise, make sure it does already exist, except for
        #   'search' which uses the CLI title as a search pattern.
        #
        title = cli_cmd.title
        raise ArgumentError, "No title provided!\nUsage: #{usage}" unless title

        validate_title title # unless title.to_s.start_with?(Xolo::DASH)

        # return if title && !title.start_with?(Xolo::DASH)

        #  raise ArgumentError, "No title provided!\nUsage: #{Xolo::Admin.usage}"
      end

      # were we given a version?
      #########
      def validate_cli_version
        # this command doesn't need a version arg
        return unless version_command? || title_or_vers_command?

        # TODO:
        #   If this is an 'add-' command, ensure the version
        #   doesn't already exist.
        #   Otherwise, make sure it does already exist
        #

        vers = cli_cmd.version
        return unless vers.to_s.empty? || vers.start_with?(Xolo::DASH)

        raise ArgumentError, "No version provided with '#{cli_cmd.command}' command!\nUsage: #{Xusage}"
      end

      # Validate the command options acquired from the command line.
      # Walkthru will validate them individually as they are entered.
      #
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
          if cli_cmd_opts[key] == Xolo::NONE && !deets[:required]
            cli_cmd_opts[key] = nil
            next
          end

          # if an item is :multi, it is an array. If it has only one item, split it on commas
          # This handles multi items being given multiple times as CLI opts, or
          # as comma-sep values in CLI opts or walkthru.
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
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      def validate_title(val)
        val = val.to_s.strip

        # TODO: Validate that it doesn't already exist in xolo if we are adding
        return val if val =~ /\A[a-z0-9-][a-z0-9-]+\z/

        raise_invalid_data_error val, TITLE_ATTRS[:title][:invalid_msg]
      end

      # validate a title display-name. Must be 3+ chars long
      #
      # @param val [Object] The value to validate
      #
      #
      # @return [String] The valid value
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
      def validate_version_script(val)
        val = Pathname.new val.to_s.strip
        return val if val.file? && val.readable? && val.read.start_with?('#!')

        raise_invalid_data_error val, TITLE_ATTRS[:version_script][:invalid_msg]
      end

      # validate an array of jamf group names to use as targets.
      # 'all', or 'none' are also acceptable
      #
      # NOTE: we will not compare targets to exclusions - we'll just verify
      # that the jamf groups exist. If a group (or an individual mac) is both a
      # target and an exclusion, the exclusion wins.
      #
      # @param val [Array<String>] The value to validate:  names of jamf comp.
      #   groups, or 'all', or 'none'
      #
      # @return [Array<String>] The valid value
      def validate_target_groups(val)
        val = [val] unless val.is_a? Array
        if  val.include? Xolo::NONE
          return []
        elsif val.include? Xolo::Admin::Title::TARGET_ALL
          return [Xolo::Admin::Title::TARGET_ALL]
        end

        bad_grps = bad_jamf_groups(val)
        return val if bad_grps.empty?

        raise_invalid_data_error bad_grps.join(', '), TITLE_ATTRSS[:target_groups][:invalid_msg]
      end

      # validate an array  of jamf groups to use as exclusions.
      # 'none' is also acceptable
      #
      # NOTE: we will not compare targets to exclusions - we'll just verify
      # that the jamf groups exist. If a group (or an individual mac) is both a
      # target and an exclusion, the exclusion wins.
      #
      # @param val [Array<String>] The value to validate:  names of jamf comp.
      #   groups, or 'none'
      #
      # @return [Array<String>] The valid value
      def validate_excluded_groups(val)
        val = [val] unless val.is_a? Array
        return [] if val.include? Xolo::NONE

        bad_grps = bad_jamf_groups(val)
        return val if bad_grps.empty?

        raise_invalid_data_error bad_grps.join(', '), TITLE_ATTRS[:excluded_groups][:invalid_msg]
      end

      # TODO: Implement this for xadm via the xolo server
      # @param grp_ary [Array<String>] Jamf groups to validate
      # @return [Array<String>] Jamf groups that do not exist.
      def bad_jamf_groups(group_ary)
        bad_groups = []
        group_ary.each { |g| bad_groups << g unless g } # is a jamf group
        bad_groups
      end

      # validate a titles expiration. Must be a non-negative integer
      #
      # @param val [Object] The value to validate
      #
      # @return [Integer] The valid value
      def validate_expiration(val)
        val = val.to_s
        val = val.to_i if val.pix_integer?

        return val if val.is_a?(Integer) && !val.negative?

        raise_invalid_data_error val, TITLE_ATTRS[:expiration][:invalid_msg]
      end

      # validate a title expiration paths. Must one or more full paths
      # starting with a / and containing at least one more.
      #
      # @param val [Object] The value to validate
      #
      # @return [Array<String>] The valid array
      def validate_expiration_paths(val)
        val = [val] unless val.is_a? Array
        return [] if val == [Xolo::NONE]

        val.map!(&:to_s)
        bad_paths = []

        val.each do |path|
          bad_paths << path unless path =~ %r{\A/\w.*/.*\z}
        end
        return val if bad_paths.empty?

        raise_invalid_data_error bad_paths.join(', '), TITLE_ATTRS[:expiration_paths][:invalid_msg]
      end

      # validate boolean options
      #
      # Never raises an error, just returns true of false based on the string value
      #
      # @param val [Object] The value to validate
      #
      # @return [Boolean] The  valid value
      def validate_boolean(val)
        val.to_s =~ TRUE_RE ? true : false
      end

      # validate a self_service_category. Must exist in Jamf Pro
      #
      # @param val [Object] The value to validate
      #
      # @return [Boolean, String] The validity, or the valid value
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
      def validate_self_service_icon(val)
        val = Pathname.new val.to_s.strip
        return val if val.file? && val.readable?

        raise_invalid_data_error val, TITLE_ATTRS[:self_service_icon][:invalid_msg]
      end

      # Version Attributes
      #
      ##################################################

      # @param val [Object] The value to validate
      #
      # @return [Date] The valid value
      def validate_publish_date(val)
        val = Time.parse val.to_s
        # TODO: ? Ensure this date is >= the prev. version and <= the next
        return val if true

        raise_invalid_data_error val, VERSION_ATTRS[:publish_date][:invalid_msg]
      rescue StandardError => e
        raise_invalid_data_error val, e.to_s
      end

      # @param val [Object] The value to validate
      #
      # @return [Gem::Version] The valid value
      def validate_min_os(val)
        val = Gem::Version.new val.to_s
        # TODO: internal consistency - make sure this is <= max_os
        return val if true

        raise_invalid_data_error val, VERSION_ATTRS[:min_os][:invalid_msg]
      rescue StandardError => e
        raise_invalid_data_error val, e.to_s
      end

      # @param val [Object] The value to validate
      #
      # @return [Gem::Version] The valid value
      def validate_max_os(val)
        val = Gem::Version.new val.to_s
        # TODO: internal consistency - make sure this is >= max_os
        return val if true

        raise_invalid_data_error val, VERSION_ATTRS[:max_os][:invalid_msg]
      rescue StandardError => e
        raise_invalid_data_error val, e.to_s
      end

      # @param val [Object] The value to validate
      #
      # @return [Array<Array<String>>] The valid value
      def validate_killapps(val)
        return [] if val.include? Xolo::NONE

        # Split every item on semicolons
        val.map! { |ka| ka.split(/\s*;\s*/) }

        val.each do |ka|
          # If it is 'use-title' then just use a one-item subarray:
          # ['use-title'] and the server will deal with it
          # TODO: Make the server validate use-title, and report error if needed
          next if ka.first == Xolo::Admin::Version::USE_TITLE_FOR_KILLAPP

          # app name must end with .app
          unless ka.first.end_with?(Xolo::DOTAPP)
            raise_invalid_data_error(
              ka.first,
              TITLE_ATTRS[:app_name][:invalid_msg]
            )
          end

          # bundle id must contain a dot
          next if ka[1]&.include?(Xolo::DOT)

          raise_invalid_data_error(
            ka[1],
            TITLE_ATTRS[:app_bundle_id][:invalid_msg]
          )
        end
        val
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
      def validate_pilot_groups(val)
        val = [val] unless val.is_a? Array
        return [] if val.include? Xolo::NONE

        bad_grps = bad_jamf_groups(val)
        return val if bad_grps.empty?

        raise_invalid_data_error bad_grps.join(', '), VERSION_ATTRS[:pilot_groups][:invalid_msg]
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
        val if response.body == Xolo::Admin::Connection::PING_RESPONSE
      rescue Faraday::ConnectionFailed => e
        raise_invalid_data_error val, Xolo::Admin::Configuration::KEYS[:hostname][:invalid_msg]
      end

      # Password (and username) will be validated via the server
      #
      # @param val [String] The passwd to be validated with the stored or given username
      #
      # @return [void]
      #######
      def validate_pw(val)
        if val.downcase == 'x'
          val = nil
          return
        end

        user = walkthru_cmd_opts[:user]
        user ||= current_opt_values[:user]
        server = walkthru_cmd_opts[:hostname]
        server ||= current_opt_values[:hostname]

        payload = { username: user, password: val }.to_json

        resp = server_cnx(host: server).post Xolo::Admin::Connection::LOGIN_ROUTE, payload
        puts resp.body

        raise_invalid_data_error 'User/Password', resp.body[:error] unless resp.success?

        # store the passwd in the keychain
        store_credentials user: user, pw: val

        # The passwd is never stored in the config, this is:
        Xolo::Admin::Configuration::CREDENTIALS_IN_KEYCHAIN
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
      def validate_version_consistency(_opts)
        true
      end

      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency(opts)
        # if we are just listing the versions, nothing to do
        return if cli_cmd.command == Xolo::Admin::Options::LIST_VERSIONS_CMD

        # order of these matters
        validate_title_consistency_app_and_script(opts)
        validate_title_consistency_app_or_script(opts)
        validate_title_consistency_app_name_and_id(opts)
        validate_title_consistency_expire_paths(opts)
        validate_title_consistency_no_all_in_ssvc(opts)
        validate_title_consistency_ssvc_needs_category(opts)
      end # title_consistency(opts)

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
        return unless opts[:expiration].to_i.positive?
        return unless opts[:expiration_paths].to_s.empty?

        msg =
          if walkthru?
            'At least one Expiration Path must be given if Expiration is > 0.'
          else
            'At least one --expiration-path must be given if --expiration is > 0'
          end
        raise_consistency_error msg
      end

      # if target_group is all, can't be in self service
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency_no_all_in_ssvc(opts)
        return unless opts[:target_groups].to_a.include?(Xolo::Admin::Title::TARGET_ALL) && opts[:self_service]

        msg =
          if walkthru?
            "Cannot be in Self Service when Target Group is '#{Xolo::Admin::Title::TARGET_ALL}'"
          else
            "--self-service cannot be used when --target-groups contains '#{Xolo::Admin::Title::TARGET_ALL}'"
          end
        raise_consistency_error msg
      end

      # if target_group is all, can't be in self service
      #
      # @param opts [OpenStruct] the current options
      #
      # @return [void]
      #######
      def validate_title_consistency_no_all_in_ssvc(opts)
        return unless opts[:target_groups].to_a.include?(Xolo::Admin::Title::TARGET_ALL) && opts[:self_service]

        msg =
          if walkthru?
            "Cannot be in Self Service when Target Group is '#{Xolo::Admin::Title::TARGET_ALL}'"
          else
            "--self-service cannot be used when --target-groups contains '#{Xolo::Admin::Title::TARGET_ALL}'"
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

    end # module validate

  end # module Core

end # module Xolo
