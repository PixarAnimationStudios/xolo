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

  module Core

    # A collection of methods implementing data constraints
    #
    # As with that module:
    # Some of these methods can take multiple input types, such as a String
    # or an number.  All of them will either raise an exception
    # if the value isn't valid, or will return a standardized form of the input
    # (e.g. a number, even if given a String)
    #
    module Validate

      COMMA_SEP_RE = /\s*,\s*/.freeze

      # Thes methods all raise this error
      def self.raise_invalid_data_error(msg)
        raise Xolo::InvalidDataError, msg
      end

      # validate a title-id. Must be 2+ chars long, only lowercase
      # alpha-numerics & dashes
      #
      # @param val [Object] The value to validate
      #
      # @param raise [Boolean] If true, raise an error when validation fails.
      #   otherwise just return false when on failure and true on success.
      #
      # @return [String] the valid title_id
      def self.title_id(val, raise: true)
        valid = val =~ /\A[a-z0-9-][a-z0-9-]+\z/ ? true : false

        # TODO: validate that it doesn't already exist in xolo
        # remember that the admin app will not talk to Jamf, only to the
        # xolo server.

        return valid unless raise
        return val if valid

        raise_invalid_data_error Xolo::Admin::Options::TITLE_OPTIONS[:title_id][:invalid_msg]
      end

      # validate a title-id. Must be 2+ chars long, only lowercase
      # alpha-numerics & dashes
      #
      # @param val [Object] The value to validate
      #
      # @param raise [Boolean] If true, raise an error when validation fails.
      #   otherwise just return false when on failure and true on success.
      #
      # @return [String] the valid title_id
      def self.title_id(val, raise: true)
        valid = val =~ /\A[a-z0-9-][a-z0-9-]+\z/ ? true : false

        # TODO: validate that these exist in Jamf.
        # remember that the admin app will not talk to Jamf, only to the
        # xolo server.

        return valid unless raise
        return val if valid

        raise_invalid_data_error Xolo::Admin::Options::TITLE_OPTIONS[:title_id][:invalid_msg]
      end

      # validate a title display-name. Must be 3+ chars long, starting and ending with
      # a non-whitespace char.
      #
      # @param val [Object] The value to validate
      #
      # @param raise [Boolean] If true, raise an error when validation fails.
      #   otherwise just return false when on failure and true on success.
      #
      # @return [String] the valid title_id
      def self.title_display_name(val, raise: true)
        valid = val =~ /\A\S.+\S\z/ ? true : false
        return valid unless raise
        return val if valid

        raise_invalid_data_error Xolo::Admin::Options::TITLE_OPTIONS[:display_name][:invalid_msg]
      end

      # validate a title description Must be 3+ chars long, starting and ending with
      # a non-whitespace char.
      #
      # @param val [Object] The value to validate
      #
      # @param raise [Boolean] If true, raise an error when validation fails.
      #   otherwise just return false when on failure and true on success.
      #
      # @return [String] the valid title_id
      def self.title_desc(val, raise: true)
        valid = val.length > 20
        return valid unless raise
        return val if valid

        raise_invalid_data_error Xolo::Admin::Options::TITLE_OPTIONS[:description][:invalid_msg]
      end

      # validate a title publisher Must be 3+ chars long, starting and ending with
      # a non-whitespace char.
      #
      # @param val [Object] The value to validate
      #
      # @param raise [Boolean] If true, raise an error when validation fails.
      #   otherwise just return false when on failure and true on success.
      #
      # @return [String] the valid title_id
      def self.publisher(val, raise: true)
        valid = val =~ /\A\S.+\S\z/ ? true : false
        return valid unless raise
        return val if valid

        raise_invalid_data_error Xolo::Admin::Options::TITLE_OPTIONS[:publisher][:invalid_msg]
      end

      # validate a title app_bundle_id Must include at least one dot
      #
      # @param val [Object] The value to validate
      #
      # @param raise [Boolean] If true, raise an error when validation fails.
      #   otherwise just return false when on failure and true on success.
      #
      # @return [String] the valid title_id
      def self.app_bundle_id(val, raise: true)
        valid = val.include? '.'
        return valid unless raise
        return val if valid

        raise_invalid_data_error Xolo::Admin::Options::TITLE_OPTIONS[:app_bundle_id][:invalid_msg]
      end

      # validate a title app_name Must end with .app
      #
      # @param val [Object] The value to validate
      #
      # @param raise [Boolean] If true, raise an error when validation fails.
      #   otherwise just return false when on failure and true on success.
      #
      # @return [String] the valid title_id
      def self.app_name(val, raise: true)
        valid = val.end_with? '.app'
        return valid unless raise
        return val if valid

        raise_invalid_data_error Xolo::Admin::Options::TITLE_OPTIONS[:app_bundle_id][:invalid_msg]
      end

      # validate an array  of jamf ggroups to use as targets.
      # 'none' is also acceptabe
      #
      # NOTE: we will not compare targets to exclusions - we'll just verify
      # that the jamf groups exist. If a group (or an individual mac) is both a
      # target and an exclusion, the exclusion wins.
      #
      # @param val [Array<String>] The value to validate names of jamf comp. groups
      #
      # @param raise [Boolean] If true, raise an error when validation fails.
      #   otherwise just return false when on failure and true on success.
      #
      # @return [String] the valid title_id
      def self.targets(val, raise: true)
        valid =
          if val == Xolo::Admin::Options::NONE
            true

          elsif val.is_a?(Array)
            bad_jamf_groups(val).empty?

          else
            false
          end

        return valid unless raise
        return val if valid

        raise_invalid_data_error Xolo::Admin::Options::TITLE_OPTIONS[:targets][:invalid_msg]
      end

      # TODO: Implement this for xadm via the xolo server
      # @param grp_ary [Array<String>] Jamf groups to validate
      # @return [Array<String>] Jamf groups that do not exist.
      def self.bad_jamf_groups(group_ary)
        bad_groups = []
        group_ary.each { |g| bad_groups << g unless g } # is a jamf group
        bad_groups
      end

      # Validate that a value is valid based on its
      # definition in an objects OAPI_PROPERTIES constant.
      #
      # @param val [Object] The value to validate
      #
      # @param klass [Class, Symbol] The class which the val must be
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [Boolean] the valid boolean
      #
      def self.option_type(val, _type)
        # check that the new val is not nil unless nil is OK
        val = not_nil(val, attr_name: attr_name) unless attr_def[:nil_ok]

        # if the new val is nil here, then nil is OK andd we shouldn't
        # check anything else
        return val if val.nil?

        val =
          case attr_def[:class]

          when Class
            class_instance val, klass: attr_def[:class], attr_name: attr_name

          when :Boolean
            boolean val, attr_name: attr_name

          when :String
            fully_validate_string(val, attr_def: attr_def, attr_name: attr_name)

          when :Integer
            fully_validate_integer(val, attr_def: attr_def, attr_name: attr_name)

          when :Number
            fully_validate_number(val, attr_def: attr_def, attr_name: attr_name)

          when :Hash
            hash val, attr_name: attr_name

          end # case

        # Now that the val is in whatever correct format after the above tests,
        # we test for enum membership if needed
        # otherwise, just return the val
        if attr_def[:enum]
          in_enum val, enum: attr_def[:enum], attr_name: attr_name
        else
          val
        end
      end

      # run all the possible validations on a string
      def self.fully_validate_string(val, attr_def:, attr_name: nil)
        val = string val, attr_name: attr_name

        min_length val, min: attr_def[:min_length], attr_name: attr_name if attr_def[:min_length]
        max_length val, max: attr_def[:max_length], attr_name: attr_name if attr_def[:max_length]
        matches_pattern val, attr_def[:pattern], attr_name: attr_name if attr_def[:pattern]

        val
      end

      # run all the possible validations on an integer
      def self.fully_validate_integer(val, attr_def:, attr_name: nil)
        val = integer val, attr_name: attr_name
        validate_numeric_constraints(val, attr_def: attr_def, attr_name: attr_name)
      end

      # run all the possible validations on a 'number'
      def self.fully_validate_number(val, attr_def:, attr_name: nil)
        val =
          if %w[float double].include? attr_def[:format]
            float val, attr_name: attr_name
          else
            number val, attr_name: attr_name
          end
        validate_numeric_constraints(val, attr_def: attr_def, attr_name: attr_name)
      end

      # run the numeric constraint validations for any numeric value
      # The number itself must already be validated
      def self.validate_numeric_constraints(val, attr_def:, attr_name: nil)
        ex_min = attr_def[:exclusive_minimum]
        ex_max = attr_def[:exclusive_maximum]
        mult_of = attr_def[:multiple_of]

        minimum val, min: attr_def[:minimum], exclusive: ex_min, attr_name: attr_name if attr_def[:minimum]
        maximum val, max: attr_def[:maximum], exclusive: ex_max, attr_name: attr_name if attr_def[:maximum]
        multiple_of val, multiplier: mult_of, attr_name: attr_name if mult_of

        val
      end

      # run the array constraint validations for an array value.
      # The individual array items  must already be validated
      def self.array_constraints(val, attr_def:, attr_name: nil)
        min_items val, min: attr_def[:minItems], attr_name: attr_name if attr_def[:minItems]
        max_items val, max: attr_def[:maxItems], attr_name: attr_name if attr_def[:maxItems]
        unique_array val, attr_name: attr_name if attr_def[:uniqueItems]

        val
      end

      # validate that a value is of a specific class
      #
      # @param val [Object] The value to validate
      #
      # @param klass [Class, Symbol] The class which the val must be an instance of
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [Object] the valid value
      #
      def self.class_instance(val, klass:, attr_name: nil, msg: nil)
        return val if val.instance_of? klass

        # try to instantiate the class with the value. It should raise an error
        # if not good
        klass.new val
      rescue StandardError => e
        unless msg
          msg = +"#{attr_name} value must be a #{klass}, or #{klass}.new must accept it as the only parameter,"
          msg << "but #{klass}.new raised: #{e.class}: #{e}"
        end
        raise_invalid_data_error(msg)
      end

      # Confirm that the given value is a boolean value, accepting
      # strings and symbols and returning real booleans as needed
      # Accepts: true, false, 'true', 'false', 'yes', 'no', 't','f', 'y', or 'n'
      # as strings or symbols, case insensitive
      #
      # TODO: use this throughout ruby-jss
      #
      # @param val [Boolean,String,Symbol] The value to validate
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [Boolean] the valid boolean
      #
      def self.boolean(val, attr_name: nil, msg: nil)
        return val if Xolo::TRUE_FALSE.include? val
        return true if val.to_s =~ /^(t(rue)?|y(es)?)$/i
        return false if val.to_s =~ /^(f(alse)?|no?)$/i

        raise_invalid_data_error(msg || "#{attr_name} value must be boolean true or false, or an equivalent string or symbol")
      end

      # Confirm that a value is an number or a string representation of an
      # number. Return the number, or raise an error
      #
      # @param val[Object] the value to validate
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [Integer]
      #
      def self.number(val, attr_name: nil, msg: nil)
        if val.ia_a?(Integer) || val.is_a?(Float)
          return val

        elsif val.is_a?(String)

          if val.j_integer?
            return val.to_i
          elsif val.j_float?
            return val.to_f
          end

        end

        raise_invalid_data_error(msg || "#{attr_name} value must be a number")
      end

      # Confirm that a value is an integer or a string representation of an
      # integer. Return the integer, or raise an error
      #
      # @param val[Object] the value to validate
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [Integer]
      #
      def self.integer(val, attr_name: nil, msg: nil)
        val = val.to_i if val.is_a?(String) && val.j_integer?
        return val if val.is_a? Integer

        raise_invalid_data_error(msg || "#{attr_name} value must be an integer")
      end

      # Confirm that a value is a Float or a string representation of a Float
      # Return the Float, or raise an error
      #
      # @param val[Object] the value to validate
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [Float]
      #
      def self.float(val, attr_name: nil, msg: nil)
        val = val.to_f if val.is_a?(Integer)
        val = val.to_f if val.is_a?(String) && (val.j_float? || val.j_integer?)
        return val if val.is_a? Float

        raise_invalid_data_error(msg || "#{attr_name} value must be an floating point number")
      end

      # Confirm that a value is a Hash
      # Return the Hash, or raise an error
      #
      # @param val[Object] the value to validate
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [Hash]
      #
      def self.object(val, attr_name: nil, msg: nil)
        return val if val.is_a? Hash

        raise_invalid_data_error(msg || "#{attr_name} value must be a Hash")
      end

      # Confirm that a value is a String
      # Return the String, or raise an error
      #
      # @param val[Object] the value to validate
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @param to_s: [Boolean] If true, this method always succeds and returns
      #  the result of calling #to_s on the value
      #
      # @return [Hash]
      #
      def self.string(val, attr_name: nil, msg: nil, to_s: false)
        val = val.to_s if to_s
        return val if val.is_a? String

        raise_invalid_data_error(msg || "#{attr_name} value must be a String")
      end

      # validate that the given value is greater than or equal to some minimum
      #
      # If exclusive, the min value is excluded from the range and
      # the value must be greater than the min.
      #
      # While intended for Numbers, this will work for any Comparable objects
      #
      # @param val [Object] the thing to validate
      #
      # @param min [Object] A value that the val must be greater than or equal to
      #
      # @param exclusuve [Boolean] Should the min be excluded from the valid range?
      #   true: val must be > min, false: val must be >= min
      #
      # @param msg [String] A custom error message when the value is invalid
      #
      # @return [String] the valid value
      #
      def self.minimum(val, min:, attr_name: nil, exclusive: false, msg: nil)
        if exclusive
          return val if val > min
        elsif val >= min
          return val
        end
        raise_invalid_data_error(msg || "#{attr_name} value must be >= #{min}")
      end

      # validate that the given value is less than or equal to some maximum
      #
      # While intended for Numbers, this will work for any Comparable objects
      #
      # If exclusive, the max value is excluded from the range and
      # the value must be less than the max.
      #
      # @param val [Object] the thing to validate
      #
      # @param max[Object] A value that the val must be less than or equal to
      #
      # @param exclusuve [Boolean] Should the max be excluded from the valid range?
      #   true: val must be < max, false: val must be <= max
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [String] the valid value
      #
      def self.maximum(val, max:, attr_name: nil, exclusive: false, msg: nil)
        if exclusive
          return val if val < max
        elsif val <= max
          return val
        end
        raise_invalid_data_error(msg || "#{attr_name} value must be <= #{max}")
      end

      # Validate that a given number is multiple of some other given number
      #
      # @param val [Number] the number to validate
      #
      # @param multiplier [Number] the number what the val must be a multiple of.
      #   this must be positive.
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [String] the valid value
      #
      def self.multiple_of(val, multiplier:, attr_name: nil, msg: nil)
        unless multiplier.is_a?(Numeric) && multiplier.positive?
          raise ArgumentError,
                'multiplier must be a positive number'
        end
        raise Xolo::InvalidDataError, 'Value must be a number' unless val.is_a?(Numeric)

        return val if (val % multiplier).zero?

        raise_invalid_data_error(msg || "#{attr_name} value must be a multiple of #{multiplier}")
      end

      # validate that the given value's length is greater than or equal to some minimum
      #
      # While this is intended for Strings, it will work for any object that responds
      # to #length
      #
      # @param val [Object] the value to validate
      #
      # @param min [Object] The minimum length allowed
      #
      # @param msg [String] A custom error message when the value is invalid
      #
      # @return [String] the valid value
      #
      def self.min_length(val, min:, attr_name: nil, msg: nil)
        raise ArgumentError, 'min must be a number' unless min.is_a?(Numeric)
        return val if val.length >= min

        raise_invalid_data_error(msg || "length of #{attr_name} value must be >= #{min}")
      end

      # validate that the given value's length is less than or equal to some maximum
      #
      # While this is intended for Strings, it will work for any object that responds
      # to #length
      #
      # @param val [Object] the value to validate
      #
      # @param max [Object] the maximum length allowed
      #
      # @param msg [String] A custom error message when the value is invalid
      #
      # @return [String] the valid value
      #
      def self.max_length(val, max:, attr_name: nil, msg: nil)
        raise ArgumentError, 'max must be a number' unless max.is_a?(Numeric)
        return val if val.length <= max

        raise_invalid_data_error(msg || "length of #{attr_name} value must be <= #{max}")
      end

      # validate that the given value contains at least some minimum number of items
      #
      # While this is intended for Arrays, it will work for any object that responds
      # to #size
      #
      # @param val [Object] the value to validate
      #
      # @param min [Object] the minimum number of items allowed
      #
      # @param msg [String] A custom error message when the value is invalid
      #
      # @return [String] the valid value
      #
      def self.min_items(val, min:, attr_name: nil, msg: nil)
        raise ArgumentError, 'min must be a number' unless min.is_a?(Numeric)
        return val if val.size >= min

        raise_invalid_data_error(msg || "#{attr_name} value must contain at least #{min} items")
      end

      # validate that the given value contains no more than some maximum number of items
      #
      # While this is intended for Arrays, it will work for any object that responds
      # to #size
      #
      # @param val [Object] the value to validate
      #
      # @param max [Object] the maximum number of items allowed
      #
      # @param msg [String] A custom error message when the value is invalid
      #
      # @return [String] the valid value
      #
      def self.max_items(val, max:, attr_name: nil, msg: nil)
        raise ArgumentError, 'max must be a number' unless max.is_a?(Numeric)
        return val if val.size <= max

        raise_invalid_data_error(msg || "#{attr_name} value must contain no more than #{max} items")
      end

      # validate that an array has only unique items, no duplicate values
      #
      # @param val [Array] The array to validate
      #
      # @param msg [String] A custom error message when the value is invalid
      #
      # @param return [Array] the valid array
      #
      def self.unique_array(val, attr_name: nil, msg: nil)
        raise ArgumentError, 'Value must be an Array' unless val.is_a?(Array)
        return val if val.uniq.size == val.size

        raise_invalid_data_error(msg || "#{attr_name} value must contain only unique items")
      end

      # validate that a value is not nil
      #
      # @param val[Object] the value to validate
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [Object] the valid value
      #
      def self.not_nil(val, attr_name: nil, msg: nil)
        return val unless val.nil?

        raise_invalid_data_error(msg || "#{attr_name} value may not be nil")
      end

      # Does a value exist in a given enum array?
      #
      # @param val [Object] The thing that must be in the enum
      #
      # @param enum [Array] the enum of allowed values
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [Object] The valid object
      #
      def self.in_enum(val, enum:, attr_name: nil, msg: nil)
        return val if enum.include? val

        raise_invalid_data_error(msg || "#{attr_name} value must be one of: #{enum.join ', '}")
      end

      # Does a string match a given regular expression?
      #
      # @param val [String] The value to match
      #
      # @param pattern [pattern] the regular expression
      #
      # @param msg[String] A custom error message when the value is invalid
      #
      # @return [Object] The valid object
      #
      def self.matches_pattern(val, pattern:, attr_name: nil, msg: nil)
        return val if val =~ pattern

        raise_invalid_data_error(msg || "#{attr_name} value does not match RegExp: #{pattern}")
      end

    end # module validate

  end # module Core

end # module Xolo
