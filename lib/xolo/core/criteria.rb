# Copyright 2018 Pixar
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

module Xolo

  # Similar to JSS::Criteriable::Criteria, but simpler.
  #
  # This class basically holds and manipulates a specialized Array containing
  # criteria, which are frozen Hashes.
  #
  # While the Array itself isn't frozen (it needs to have criteria added and
  # removed) accessing it from outside the class will give you a frozen
  # dup of it. The only way to add or remove criteria are with the append,
  # prepend, insert and delete methods provided.
  #
  # Each criterion is a frozen Hash with these keys:
  #
  # and_or: [Symbol]
  #   Either :and or :or
  #   How this criterion is combined with the one before it in the array.
  #   Meaningless for the first criterion in the array. Default is :and.
  #   NOTE: there is no ability to parenthesize the criteria
  #
  # type: [Symbol]
  #   Either :recon or :ea.
  #
  #   :recon means the field_name refers to a value gathered during recons
  #   (including normal ext. attrs)
  #
  #   :ea, means the field_name is the name of a d3/patch-specific ext.
  #   attribute defined in the Xolo::Title containing this criterion.
  #
  # field_name: [String]
  #   The 'field' of computer data being used in this criterion,
  #   e.g. 'Application Bundle ID' or the name of an Extension Attribute
  #
  # operator: [String]
  #   the operator for evaluating the value, one of the values
  #   in OPERATORS
  #
  # value: [String]
  #   The value to evaluate with the operator
  #
  # These keys are also used as parameters for the append_criterion,
  # prepend_criterion, and insert_criterion methods. When using those
  # methods to add a criterion, the Hash is validated and then frozen, so
  # it can't be edited. Use the delete_criterion method to remove them.
  #
  # Those methods can also take a single delimited string as defined in
  # the extended help output for d3admin. See `d3admin --ext add-title --help`
  # The string is split and parsed into the hash, and then validated.
  #
  # Xolo::Criteria are used in Patch Source data in three ways:
  #
  # - In JSON 'Software Title' Objects (from Xolo::Title)
  #
  #   -  Title installed-criteria, aka 'requirements'
  #      An array of criteria that define which managed computers
  #      have any version of the title installed. Stored in
  #      Xolo::Title#installed_criteria
  #
  # - in JSON 'Patch' Objects (from Xolo::Version)
  #
  #   - Version eligibility-criteria, aka  'capabilities'
  #     An array of criteria that define which managed computers
  #     may install this specific version. Stored in
  #     Xolo::Version#eligibility_criteria
  #
  #   - Version installed-criteria, inside 'components'
  #     An array of ONE component object which has a criteria object
  #     that defines the which managed computers have this version installed.
  #     Stored in  Xolo::Version#installed_criteria
  #
  class Criteria

    OPERATORS = JSS::Criteriable::Criterion::SEARCH_TYPES

    TYPES = {
      recon: 'recon',
      EA: 'extensionAttribute'
    }.freeze

    AND_OR = %i[and or].freeze

    DEFINITION_SEPARATOR = /\s*,\s*/

    # Initialization with json data re-creates a full Criteria instance.
    # This is used for sending data between the d3admin tools and the server.
    #
    # Without JSON data, no criteria are defined in initialization, and will
    # need to be added via instance methods.
    #
    def initialize(from_json: nil)
      @criteria = from_json ? from_json : []
      @criteria.each(&:freeze)
    end

    # Parse a criterion string as comes from d3admin into a Hash
    # See the extended help output from `d3admin -ext add-title --help`
    #
    # @param crtn_string [String] a criterion string as comes from d3admin
    #
    # @return [Hash] the criterion as a Hash
    #
    def parse_criterion_string(crtn_string)
      val, op, field, type, andor = crtn_string.strip.split(DEFINITION_SEPARATOR).reverse
      andor ||= 'and'
      { and_or: andor.to_sym, type: type, field_name: field, operator: op, value: val }
    end

    # An Array of Hashes which collectively define which computers
    # in your environment have this software title (any version) installed.
    #
    # A frozen dup is returned, so that the only way to modifiy the array is
    # with the modification methods below:
    #
    # @return [Array<Xolo::Criterion>] A frozen dup of the current criteria
    #
    def criteria
      @criteria.dup.freeze
    end

    def empty?
      @criteria.empty?
    end

    # Add a new Xolo::Criterion to the end of the criteria
    #
    # @param criterion[Xolo::Criterion] the new Criterion to store
    #
    # @return [void]
    #
    def append_criterion(**criterion)
      criterion = parse_criterion_string criterion if criterion.is_a? String
      validate(criterion)
      criterion.freeze
      @criteria << criterion
    end

    # Add a new Xolo::Criterion to the beginning of the criteria
    #
    # @param criterion[JSS::Criteriable::Criterion] the new Criterion to store
    #
    # @return [void]
    #
    def prepend_criterion(**criterion)
      criterion = parse_criterion_string criterion if criterion.is_a? String
      validate(criterion)
      criterion.freeze
      @criteria.unshift criterion
    end

    # Add a new Xolo::Criterion to the middle of the criteria
    #
    # @param idx[Integer] the index at which to insert the new one.
    #
    # @param criterion[Xolo::Criterion] the new Criterion to store at that index
    #
    # @return [void]
    #
    def insert_criterion(idx, criterion)
      criterion = parse_criterion_string criterion if criterion.is_a? String
      validate(criterion)
      criterion.freeze
      @criteria.insert idx, criterion
    end

    # Remove a Xolo::Criterion from the requirement
    #
    # @param idx[Integer] the index of the criterion to delete
    #
    # @return [void]
    #
    def delete_criterion(idx)
      @criteria.delete_at idx
    end

    def patch_source_data
      @criteria.map do |ctn|
        {
          name: ctn[:field_name],
          operator: ctn[:operator],
          value: ctn[:value],
          type: TYPES[ctn[:type]],
          and: (ctn[:and_or] == :and)
        }
      end
    end

    def validate(criterion)
      criterion[:and_or] ||= :and

      JSS::Validate.non_empty_string criterion[:field_name], 'Criteria field_name cannot be empty'

      raise JSS::InvalidDataError, 'Invalid operator' unless OPERATORS.include? criterion[:operator]

      raise JSS::InvalidDataError, "type: must be one of: :#{TYPES.keys.join ', :'}" unless TYPES.key? criterion[:type]

      return criterion if AND_OR.include? criterion[:and_or]

      raise JSS::InvalidDataError, "and_or: must be ':and' or ':or'."
    end

  end # class Criteria

end # module Xolo
