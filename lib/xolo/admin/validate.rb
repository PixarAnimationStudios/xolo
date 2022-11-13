# Copyright 2022 Pixar
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

      COMMA_SEP_RE = /\s*,\s*/.freeze
      TRUE_RE = /(\Atrue\z)|(\Ay(es)?\z)/i.freeze

      # Thes methods all raise this error
      def self.raise_invalid_data_error(val, msg)
        raise Xolo::InvalidDataError, "'#{val}' #{msg}"
      end

      # Validate the command options acquired from the command line.
      # Walkthru will validate them individually as they are entered.
      #
      #
      def self.cli_cmd_opts
        cmd = Xolo::Admin::Options.cli_cmd.command
        opts_defs = Xolo::Admin::Options::COMMANDS[cmd][:opts]
        return if opts_defs.empty?

        opts_defs.each do |key, deets|
          # skip things not given on the command line
          next unless Xolo::Admin::Options.cli_cmd_opts["#{key}_given"]

          # skip things that shouldn't be validated
          next unless deets[:validate]

          # if the item is not required, and 'none' is given, set the
          # value to nil and we're done
          if Xolo::Admin::Options.cli_cmd_opts[key] == Xolo::NONE && !deets[:required]
            Xolo::Admin::Options.cli_cmd_opts[key] = nil
            next
          end

          meth = deets[:validate].is_a?(Symbol) ? deets[:validate] : key

          # run the validation, which raises an error if invalid, or returns
          # the converted value if OK - the converted value replaces the original in the
          # cmd_opts
          Xolo::Admin::Options.cli_cmd_opts[key] = send meth, Xolo::Admin::Options.cli_cmd_opts[key]
        end

        # if we are here, eveything on the commandline checked out, so now
        # go through the opts_defs keys, and for any that were not given on the command line,
        # add the value for that key from current_opt_values to Xolo::Admin::Options.cli_cmd_opts
        # which will then be passed for internal consistency validation.
      end

      # validate a Xolo title. Must be 2+ chars long, only lowercase
      # alpha-numerics & dashes
      #
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      def self.title(val)
        val = val.to_s.strip
        # TODO: Validate that it doesn't already exist in xolo if we are adding
        return val if val =~ /\A[a-z0-9-][a-z0-9-]+\z/

        raise_invalid_data_error val, Xolo::Admin::Title::ATTRIBUTES[:title][:invalid_msg]
      end

      # validate a title display-name. Must be 3+ chars long
      #
      # @param val [Object] The value to validate
      #
      #
      # @return [String] The valid value
      def self.title_display_name(val)
        val = val.to_s.strip
        return val if val =~ /\A\S.+\S\z/

        raise_invalid_data_error val, Xolo::Admin::Title::ATTRIBUTES[:display_name][:invalid_msg]
      end

      # validate a title description. Must be 20+ chars long
      #
      # @param val [Object] The value to validate
      #
      # @return [Boolean, String] The validity, or the valid value
      def self.title_desc(val)
        val = val.to_s.strip
        return val if val.length >= 20

        raise_invalid_data_error val, Xolo::Admin::Title::ATTRIBUTES[:description][:invalid_msg]
      end

      # validate a title publisher. Must be 3+ chars long
      #
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      def self.publisher(val)
        val = val.to_s.strip
        return val if val.length >= 3

        raise_invalid_data_error val, Xolo::Admin::Title::ATTRIBUTES[:publisher][:invalid_msg]
      end

      # validate a title app_name. Must end with .app
      #
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      def self.app_name(val)
        val = val.to_s.strip
        return val if val.end_with? '.app'

        raise_invalid_data_error val, Xolo::Admin::Title::ATTRIBUTES[:app_bundle_id][:invalid_msg]
      end

      # validate a title app_bundle_id. Must include at least one dot
      #
      # @param val [Object] The value to validate
      #
      # @return [String] The valid value
      def self.app_bundle_id(val)
        val = val.to_s.strip
        return val if val.include? '.'

        raise_invalid_data_error val, Xolo::Admin::Title::ATTRIBUTES[:app_bundle_id][:invalid_msg]
      end

      # validate a title version script. Must start with '#!'
      #
      # @param val [Object] The value to validate
      #
      # @return [Pathname] The valid value
      def self.version_script(val)
        val = Pathname.new val.to_s.strip
        return val if val.file? && val.readable? && val.read.start_with?('#!')

        raise_invalid_data_error val, Xolo::Admin::Title::ATTRIBUTES[:version_script][:invalid_msg]
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
      def self.target_groups(val)
        val = [val] unless val.is_a? Array
        if  val.include? Xolo::NONE
          return []
        elsif val.include? Xolo::Admin::Title::TARGET_ALL
          return [Xolo::Admin::Title::TARGET_ALL]
        end

        bad_grps = bad_jamf_groups(val)
        return val if bad_grps.empty?

        raise_invalid_data_error bad_grps.join(', '), Xolo::Admin::Title::ATTRIBUTES[:target_groups][:invalid_msg]
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
      def self.excluded_groups(val)
        val = [val] unless val.is_a? Array
        return [] if val.include? Xolo::NONE

        bad_grps = bad_jamf_groups(val)
        return val if bad_grps.empty?

        raise_invalid_data_error bad_grps.join(', '), Xolo::Admin::Title::ATTRIBUTES[:excluded_groups][:invalid_msg]
      end

      # TODO: Implement this for xadm via the xolo server
      # @param grp_ary [Array<String>] Jamf groups to validate
      # @return [Array<String>] Jamf groups that do not exist.
      def self.bad_jamf_groups(group_ary)
        bad_groups = []
        group_ary.each { |g| bad_groups << g unless g } # is a jamf group
        bad_groups
      end

      # validate a titles expiration. Must be a non-negative integer
      #
      # @param val [Object] The value to validate
      #
      # @return [Integer] The valid value
      def self.expiration(val)
        val = val.to_s
        val = val.to_i if val.pix_integer?

        return val if val.is_a?(Integer) && !val.negative?

        raise_invalid_data_error val, Xolo::Admin::Title::ATTRIBUTES[:expiration][:invalid_msg]
      end

      # validate a title expiration paths. Must one or more full paths
      # starting with a / and containing at least one more.
      #
      # @param val [Object] The value to validate
      #
      # @return [Array<String>] The valid array
      def self.expiration_paths(val)
        val = [val] unless val.is_a? Array
        return [] if val == [Xolo::NONE]

        val.map!(&:to_s)
        bad_paths = []

        val.each do |path|
          bad_paths << path unless path =~ %r{\A/\w.*/.*\z}
        end
        return val if bad_paths.empty?

        raise_invalid_data_error bad_paths.join(', '), Xolo::Admin::Title::ATTRIBUTES[:expiration_paths][:invalid_msg]
      end

      # validate self service boolean
      #
      # Never raises an error, just returns true of false based on the string value
      #
      # @param val [Object] The value to validate
      #
      # @return [Boolean] The  valid value
      def self.self_service(val)
        val.to_s =~ TRUE_RE ? true : false
      end

      # validate a self_service_category. Must exist in Jamf Pro
      #
      # @param val [Object] The value to validate
      #
      # @return [Boolean, String] The validity, or the valid value
      def self.self_service_category(val)
        val = val.to_s

        # TODO: implement the check via the xolo server
        return val # if category exists

        raise_invalid_data_error val, Xolo::Admin::Title::ATTRIBUTES[:self_service_category][:invalid_msg]
      end

      # validate a path to a self_service_icon. Must exist locally and be readable
      #
      # @param val [Object] The value to validate
      #
      # @return [Boolean, String] The validity, or the valid value
      def self.self_service_icon(val)
        val = Pathname.new val.to_s.strip
        return val if val.file? && val.readable?

        raise_invalid_data_error val, Xolo::Admin::Title::ATTRIBUTES[:self_service_icon][:invalid_msg]
      end

      # Internal Consistency Checks!
      #
      ##################################################

      # Thes methods all raise this error
      def self.raise_consistency_error(msg)
        raise Xolo::InvalidDataError, msg
      end

      # Given an ostruct of options that have been individually validated, and combined
      # with any current_opt_values as needed, check the data for internal consistency.
      # The unset values in the ostruct should be nil. 'none' is used for unsetting values,
      # in the CLI and walkthru, and is converted to nil during validation if appropriate.
      #
      def self.internal_consistency(opts)
        if Xolo::Admin::CommandLine.version_command?
          version_consistency opts
        else
          title_consistency opts
        end
      end

      #######
      def self.title_consistency(opts)
        # if app_name or app_bundle_id is given, can't use --version-script
        if opts[:version_script] && (opts[:app_bundle_id] || opts[:app_name])
          msg =
            if Xolo::Admin::Options.walkthru?
              'Version Script cannot be used with App Name or App Bundle ID'
            else
              '--version-script cannot be used with --app-name or --app-bundle-id'
            end

          raise_consistency_error msg
        end

        # if app_name or app_bundle_id are given, so must the other
        if (opts[:app_name] && !opts[:app_bundle_id]) || (opts[:app_bundle_id] && !opts[:app_name])
          msg =
            if Xolo::Admin::Options.walkthru?
              'App Name & App Bundle ID must both be given if either is.'
            else
              '--app-name & --app-bundle-id must both be given if either is.'
            end
          raise_consistency_error msg
        end

        # But either version_script OR app name and bundle id must be given
        if !opts[:version_script] && !opts[:app_bundle_id]
          msg =
            if Xolo::Admin::Options.walkthru?
              'Either App Name & App Bundle ID. or Version Script must be given.'
            else
              'Must provide either -app-name & --app-bundle-id OR --version-script'
            end
          raise_consistency_error msg
        end

        # if expiration is > 0, there must be at least one expiration path
        if opts[:expiration].to_i.positive? && (!opts[:expiration_paths] || opts[:expiration_paths].empty?)
          msg =
            if Xolo::Admin::Options.walkthru?
              'At least one Expiration Path must be given if Expiration is > 0.'
            else
              'At least one --expiration-path must be provided if --expiration is > 0'
            end
          raise_consistency_error msg
        end

        # if target_group is all, can't be in self service
        if opts[:target_groups] && opts[:target_groups].include?(Xolo::Admin::Title::TARGET_ALL) && opts[:self_service]
          msg =
            if Xolo::Admin::Options.walkthru?
              "Cannot be in Self Service when Target Group is '#{Xolo::Admin::Title::TARGET_ALL}'"
            else
              "--self-service cannot be used when --target-groups contains '#{Xolo::Admin::Title::TARGET_ALL}'"
            end
          raise_consistency_error msg
        end

        # if in self service, a category must be assigned
        if opts[:self_service] && !opts[:self_service_category]
          msg =
            if Xolo::Admin::Options.walkthru?
              'A Self Service Category must be given if Self Service is true.'
            else
              'A --self-service-category must be provided when using --self-service'
            end
          raise_consistency_error msg
        end
      end # title_consistency(opts)

    end # module validate

  end # module Core

end # module Xolo
