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
#

# main module
module Xolo

  module Core

    module BaseClasses

      # The base class for objects that are instantiated from 
      # a JSON Hash
      class JSONObject

        # Constants
        ######################

        # When using prettyprint, don't spit out these instance variables.
        PP_OMITTED_INST_VARS = %i[@init_data].freeze

        # Attributes
        ######################
        
        # @return [Hash] The raw JSON data this object was instantiated with
        attr_reader :init_data

        # Public Class Methods
        ######################

        # by default, instances of subclasses are mutable
        # as a whole (even if some attributes are readonly)
        # To make them immutable, they should extend
        # Xolo::Mixins::Immutable, which overrides
        # this method
        def self.mutable?
          true
        end

        # create getters and setters for subclasses of JSONObject
        # based on their JSON_ATTRIBUTES Hash.
        #
        # This method can't be private, cuz we want to call it from a
        # Zeitwerk callback when subclasses are loaded.
        ##############################
        def self.parse_json_attributes
          # nothing to do if JSON_ATTRIBUTES is not defined for this class
          return unless defined? self::JSON_ATTRIBUTES
          
          self::JSON_ATTRIBUTES.each do |attr_name, attr_def|
            if attribute_already_parsed?(attr_name)
              Xolo.load_msg "Ancestor of #{self} has already parsed attribute #{attr_name}"
              next
            end

            Xolo.load_msg "Creating getters and setters for attribute '#{attr_name}' of #{self}"

            # TODO: Implement list-methods 
            # create_list_methods(attr_name, attr_def) if need_list_methods

            # there can be only one (primary ident)
            if attr_def[:identifier] == :primary
              raise Xolo::UnsupportedError, 'Two identifiers marked as :primary' if @got_primary

              @got_primary = true
            end

            # create getter unless the attr is write only
            create_getters attr_name, attr_def unless attr_def[:writeonly]

            # Don't crete setters for readonly attrs, or immutable objects
            create_setters attr_name, attr_def unless attr_def[:readonly] || !mutable?
            
            json_attributes_parsed << attr_name
          end #  do |attr_name, attr_def|
        end # parse_object_model

        # have we already parsed our JSON_ATTRIBUTES? If so,
        # we shoudn't do it again, and this can be used to check
        def self.json_attributes_parsed
          @json_attributes_parsed ||= []
        end      
            
        # Used by auto-generated setters and .create to validate new values.
        #
        # returns a valid value or raises an exception
        #
        # This method only validates single values. When called from multi-value
        # setters, it is used for each value individually.
        #
        # @param attr_name[Symbol], a top-level key from OAPI_PROPERTIES for this class
        #
        # @param value [Object] the value to validate for that attribute.
        #
        # @return [Object] The validated, possibly converted, value.
        #
        def self.validate_attr(attr_name, value)
          attr_def = self::JSON_ATTRIBUTES[attr_name]
          raise ArgumentError, "Unknown attribute: #{attr_name} for #{self} objects" unless attr_def

          # validate the value based on the OAPI definition.
          Xolo::Core::Validate.json_attr value, attr_def: attr_def, attr_name: attr_name
        end # validate_attr(attr_name, value)
        
        # Private Class Methods
        #####################################

        # has one of our superclasses already parsed this attribute?
        ##############################
        def attribute_already_parsed?(attr_name)
          superclass.respond_to?(:json_attributes_parsed) && superclass.json_attributes_parsed.include?(attr_name)
        end

        # create a getter for an attribute, and any aliases needed
        ##############################
        def self.create_getters(attr_name, attr_def)
          Xolo.load_msg "Creating getter method #{self}##{attr_name}"

          # multi_value - only return a frozen dup, no direct editing of the Array
          if attr_def[:multi]
            define_method(attr_name) do
              initialize_multi_value_attr_array attr_name

              instance_variable_get("@#{attr_name}").dup.freeze
            end

          # single value
          else
            define_method(attr_name) { instance_variable_get("@#{attr_name}") }
          end

          # all booleans get predicate ? aliases
          alias_method("#{attr_name}?", attr_name) if attr_def[:class] == :Boolean
        end # create getters
        private_class_method :create_getters

        # create setter(s) for an attribute, and any aliases needed
        ##############################
        def self.create_setters(attr_name, attr_def)
          # multi_value
          if attr_def[:multi]
            create_array_setters(attr_name, attr_def)
          
            # single value
          else  
            Xolo.load_msg "Creating setter method #{self}##{attr_name}="

            define_method("#{attr_name}=") do |new_value|
              new_value = validate_attr attr_name, new_value
              old_value = instance_variable_get("@#{attr_name}")
              return if new_value == old_value

              instance_variable_set("@#{attr_name}", new_value)
              note_unsaved_change attr_name, old_value
            end # define method
          end
        end # create_setters
        private_class_method :create_setters

        ##############################
        def self.create_array_setters(attr_name, attr_def)
          create_full_array_setters(attr_name, attr_def)
          create_append_setters(attr_name, attr_def)
          create_prepend_setters(attr_name, attr_def)
          create_insert_setters(attr_name, attr_def)
          create_delete_setters(attr_name, attr_def)
          create_delete_at_setters(attr_name, attr_def)
          create_delete_if_setters(attr_name, attr_def)
        end # def create_multi_setters
        private_class_method :create_array_setters

        # The  attr=(newval) setter method for array values
        ##############################
        def self.create_full_array_setters(attr_name, attr_def)
          Xolo.load_msg "Creating multi-value setter method #{self}##{attr_name}="

          define_method("#{attr_name}=") do |new_value|
            initialize_multi_value_attr_array attr_name

            raise Xolo::InvalidDataError, "Value for '#{attr_name}=' must be an Array" unless new_value.is_a? Array

            # validate each item of the new array
            new_value.map! { |item| validate_attr attr_name, item }

            # now validate the array as a whole for oapi constraints
            Xolo::Core::Validate.array_constraints(new_value, attr_def: attr_def, attr_name: attr_name)

            old_value = instance_variable_get("@#{attr_name}")
            return if new_value == old_value

            instance_variable_set("@#{attr_name}", new_value)
            note_unsaved_change attr_name, old_value
          end # define method

          return unless attr_def[:aliases]
        end # create_full_array_setter
        private_class_method :create_full_array_setters

        # The  attr_append(newval) setter method for array values
        ##############################
        def self.create_append_setters(attr_name, attr_def)
          Xolo.load_msg "Creating multi-value setter method #{self}##{attr_name}_append"

          define_method("#{attr_name}_append") do |new_value|
            initialize_multi_value_attr_array attr_name

            new_value = validate_attr attr_name, new_value

            new_array = instance_variable_get("@#{attr_name}")
            old_array = new_array.dup
            new_array << new_value

            # now validate the array as a whole for oapi constraints
            Xolo::Core::Validate.array_constraints(new_array, attr_def: attr_def, attr_name: attr_name)

            note_unsaved_change attr_name, old_array
          end # define method

          # always have a << alias
          alias_method "#{attr_name}<<", "#{attr_name}_append"
        end # create_append_setters
        private_class_method :create_append_setters

        # The  attr_prepend(newval) setter method for array values
        ##############################
        def self.create_prepend_setters(attr_name, attr_def)
          Xolo.load_msg "Creating multi-value setter method #{self}##{attr_name}_prepend"

          define_method("#{attr_name}_prepend") do |new_value|
            initialize_multi_value_attr_array attr_name

            new_value = validate_attr attr_name, new_value

            new_array = instance_variable_get("@#{attr_name}")
            old_array = new_array.dup
            new_array.unshift new_value

            # now validate the array as a whole for oapi constraints
            Xolo::Core::Validate.array_constraints(new_array, attr_def: attr_def, attr_name: attr_name)

            note_unsaved_change attr_name, old_array
          end # define method
        end # create_prepend_setters
        private_class_method :create_prepend_setters

        # The  attr_insert(index, newval) setter method for array values
        def self.create_insert_setters(attr_name, attr_def)
          Xolo.load_msg "Creating multi-value setter method #{self}##{attr_name}_insert"

          define_method("#{attr_name}_insert") do |index, new_value|
            initialize_multi_value_attr_array attr_name

            new_value = validate_attr attr_name, new_value

            new_array = instance_variable_get("@#{attr_name}")
            old_array = new_array.dup
            new_array.insert index, new_value

            # now validate the array as a whole for oapi constraints
            Xolo::Core::Validate.array_constraints(new_array, attr_def: attr_def, attr_name: attr_name)

            note_unsaved_change attr_name, old_array
          end # define method
        end # create_insert_setters
        private_class_method :create_insert_setters

        # The  attr_delete(val) setter method for array values
        ##############################
        def self.create_delete_setters(attr_name, attr_def)
          Xolo.load_msg "Creating multi-value setter method #{self}##{attr_name}_delete"

          define_method("#{attr_name}_delete") do |val|
            initialize_multi_value_attr_array attr_name

            new_array = instance_variable_get("@#{attr_name}")
            old_array = new_array.dup
            new_array.delete val
            return if old_array == new_array

            # now validate the array as a whole for oapi constraints
            Xolo::Core::Validate.array_constraints(new_array, attr_def: attr_def, attr_name: attr_name)

            note_unsaved_change attr_name, old_array
          end # define method
        end # create_insert_setters
        private_class_method :create_delete_setters

        # The  attr_delete_at(index) setter method for array values
        ##############################
        def self.create_delete_at_setters(attr_name, attr_def)
          Xolo.load_msg "Creating multi-value setter method #{self}##{attr_name}_delete_at"

          define_method("#{attr_name}_delete_at") do |index|
            initialize_multi_value_attr_array attr_name

            new_array = instance_variable_get("@#{attr_name}")
            old_array = new_array.dup
            deleted = new_array.delete_at index
            return unless deleted

            # now validate the array as a whole for oapi constraints
            Xolo::Core::Validate.array_constraints(new_array, attr_def: attr_def, attr_name: attr_name)

            note_unsaved_change attr_name, old_array
          end # define method
        end # create_insert_setters
        private_class_method :create_delete_at_setters

        # The  attr_delete_if(block) setter method for array values
        ##############################
        def self.create_delete_if_setters(attr_name, attr_def)
          Xolo.load_msg "Creating multi-value setter method #{self}##{attr_name}_delete_if"

          define_method("#{attr_name}_delete_if") do |&block|
            initialize_multi_value_attr_array attr_name

            new_array = instance_variable_get("@#{attr_name}")
            old_array = new_array.dup
            new_array.delete_if(&block)
            return if old_array == new_array

            # now validate the array as a whole for oapi constraints
            Xolo::Core::Validate.array_constraints(new_array, attr_def: attr_def, attr_name: attr_name)

            note_unsaved_change attr_name, old_array
          end # define method
        end # create_insert_setters
        private_class_method :create_delete_if_setters
    
      
        # Constructor
        ######################
        def initialize(json_data)
          @init_data = json_data
          @init_data.each do |key, val|
            next unless respond_to?(key) || respond_to?("#{key}=")

            instance_variable_set "@#{key}", val.dup
          end
        end

        
        # Public Instance Methods
        #####################

        # @return [Hash] The data to be sent to the API, as a Hash
        #  to be converted to JSON before sending to the JPAPI
        #
        def to_api
          api_data = {}
          self.class::JSON_ATTRIBUTES.each do |attr_name, attr_def|
            raw_value = instance_variable_get "@#{attr_name}"
            api_data[attr_name] = attr_def[:multi] ? multi_to_api(raw_value, attr_def) : single_to_api(raw_value, attr_def)
          end
          api_data
        end

        # @return [String] the JSON to be sent to the API for this
        #   object
        #
        def to_json(*_args)
          to_api.to_json
        end

        # Only selected items are displayed with prettyprint
        # otherwise its too much data in irb.
        #
        # @return [Array] the desired instance_variables
        #
        def pretty_print_instance_variables
          @pp_inst_vars ||= instance_variables - PP_OMITTED_INST_VARS
        end

      
        # Private Instance Methods
        #####################################
        private

        # Initialize a multi-values attribute as an empty array
        # if it hasn't been created yet
        def initialize_multi_value_attr_array(attr_name)
          return if instance_variable_get("@#{attr_name}").is_a? Array

          instance_variable_set("@#{attr_name}", [])
        end

        def note_unsaved_change(attr_name, old_value)
          return unless self.class.mutable?

          @unsaved_changes ||= {}
          new_val = instance_variable_get "@#{attr_name}"
          if @unsaved_changes[attr_name]
            @unsaved_changes[attr_name][:new] = new_val
          else
            @unsaved_changes[attr_name] = { old: old_value, new: new_val }
          end
        end

        # wrapper for class method
        def validate_attr(attr_name, value)
          self.class.validate_attr attr_name, value
        end

        # call to_api on a single value if it knows that method
        #
        def single_to_api(raw_value, _attr_def)
          raw_value.respond_to?(:to_api) ? raw_value.to_api : raw_value
        end

        # Call to_api on an array value
        #
        def multi_to_api(raw_array, attr_def)
          raw_array ||= []
          raw_array.map { |raw_value| single_to_api(raw_value, attr_def) }.compact
        end

      end # class JSONObject

    end # module BaseClasses

  end # module Core

end # module Xolo
