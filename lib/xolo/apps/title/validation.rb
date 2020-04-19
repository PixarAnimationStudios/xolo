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

  class Title < AbstractTitle

    # Methods for validating data in d3admin
    # Some validation methods just raise errors if things aren't right.
    #
    # Others take data in one form, and if it is valid, return it in a different
    # form.
    #
    # E.g. given a group name, if the group exists, its id is returned.
    # If not, an error is raised.
    #

    # Constants
    ##############################

    VALID_NAME_REGEX = /^\w+$/

    # Class Methods
    #################################

    def self.validate_title_exists(name)
      raise JSS::NoSuchItemError, "No such title: #{name}" unless exist?(name)
    end

    def self.validate_unique_name(name)
      raise JSS::AlreadyExistsError, "Title named '#{name}' already exists" if exist?(name)
    end

    # Private instance methods
    #########################

    private

    #### Instance Validators

    # Names are the unique identifiers for titles and are
    # only set when instantiated for creation.
    # Once instantiated, the name cannot be changed.
    #
    # @param name [String] the name to validate for a new Title
    #
    # @return [String] the validated name
    #
    def validate_name(name)
      JSS::Validate.non_empty_string name, 'name: must be provided'
      raise "There is already a title named '#{name}' in d3" if self.class.all_names.include? name
      raise 'Title names can only contain letters, digits and underscores (seealso display_name)' unless name =~ VALID_NAME_REGEX
      name
    end

    # Title display names must be a String or nil, when
    # nil (or empty) the name is used as the display name.
    # Empty strings are converted to nil
    #
    # @param name [String, nil] the name to validate
    #
    # @return [String, nil] the validated name
    #
    def validate_display_name(name)
      case name
      when nil
        return name
      when JSS::BLANK
        return nil
      when String
        return name
      end
      raise 'display_name must be a string or nil'
    end

    # Check that a d3 ext. attr exists with the given name
    # Raise error if it does not.
    #
    # @param name [String] the name to validate
    #
    # @return [void]
    #
    # def validate_ext_attr_exists(name)
    #   return if current_d3_extension_attribs.include? name
    #   raise JSS::NoSuchItemError, "No d3/patch extension attribute '#{name}'"
    # end

    # The description must be a meaningful non-empty string.
    # Here's how we try to enforce meaningfulness:
    #
    # Contains a URL  (http or https)
    #
    # At least 30 chars...
    #
    # ... unless it starts with 'install', in which case it must be 50 chars.
    # This is to try to prevent, e.g.:
    #
    #    'Installer for XYZ' or 'Installs XYZ'
    #
    # which are not meaningful
    #
    # @param dsec [String] the description to validate
    #
    # @return [String] the validated description
    #
    def validate_description(desc)
      JSS::Validate.non_empty_string desc, 'a description must be provided'

      # if it contains a URL, all is good
      return desc if desc =~ %r{https?://}

      # if it starts with 'install' must be 50 chars, otherwise, 30
      minlen = desc =~ /^install/i ? 50 : 30

      return desc if desc.length >= minlen

      raise JSS::InvalidDataError, "Description too short. Describe what this is, why it's here, and/or where it came from. 'Installs #{display_name}' is not useful. Must be 50 chars, or contain a web URL"
    end

    # Check the validity of a category name
    # Raise an exception if not valid.
    # nil and empty strings are acceptable to unset the category.
    #
    # @param cat[String, nil] the category to check
    #
    # @return [Integer] the jss id of the category
    #
    def validate_category(cat)
      return '' if cat.to_s.empty?
      id = JSS::Category.map_all_ids_to(:name).invert[cat]
      return id if id
      raise JSS::NoSuchItemError, "No category '#{cat}' in Jamf Pro"
    end

    # publisher must be set as a non-empty string
    #
    # @param pub[String] the publisher to check
    #
    # @return [String] the valid publisher
    #
    def validate_publisher(pub)
      JSS::Validate.non_empty_string pub, 'publisher must be a non-empty string'
    end

    # Raise an error if the given group name can't be a pilot-install
    # group because:
    #
    #  - It's already an excluded group
    # or
    #  - It doesn't exist in the JSS
    #
    # @param group[String] the group name to check
    #
    # @return [Integer] the id of the valid  group
    #
    def validate_pilot_group(group)
      id = JSS::ComputerGroup.map_all_ids_to(:name).invert[group]
      raise JSS::NoSuchItemError, "No computer group '#{group}' in Jamf Pro" unless id
      raise JSS::InvalidDataError, "Group '#{group}' is excluded for this title." if excluded_group_ids.include? id
      id
    end

    # Raise an error if the given group name can't be an auto-install
    # group because:
    #
    #  - It's already an excluded group
    # or
    #  - It doesn't exist in the JSS
    #
    # @param group[String] the group name to check
    #
    # @return [Integer] the id of the valid  group
    #
    def validate_auto_group(group)
      id = JSS::ComputerGroup.map_all_ids_to(:name).invert[group]
      raise JSS::NoSuchItemError, "No computer group '#{group}' in Jamf Pro" unless id
      raise JSS::InvalidDataError, "Group '#{group}' is excluded for this title." if excluded_group_ids.include? id
      id
    end

    # Raise an error if the given group name can't be an excluded
    # group because:
    #
    #  - It's already an auto-install group
    # or
    #  - It doesn't exist in the JSS
    #
    # @param group[String] the group name to check
    #
    # @return [Integer] the id of the valid  group
    #
    def validate_excluded_group(group)
      id = D3.computer_groups[group]
      raise JSS::NoSuchItemError, "No computer group '#{group}' in Jamf Pro" unless id
      raise JSS::InvalidDataError, "Group '#{group}' auto-installs this title." if auto_group_ids.include? id
      id
    end

    # Confirm the validity of an expiration.
    # Raise an exception if invalid.
    #
    # @param days[Integer,nil,false] the expiration to check
    #
    # @return [Integer] the valid expiration
    #
    def validate_expiration(days)
      days ||= 0
      JSS::Validate.integer days, 'Expiration must be a non-negative Integer.'
      days = 0 if days.negative?
      days
    end

    def validate_expiration_bundle_id(id)
      JSS::Validate.non_empty_string id
    end

    # Confirm the validity of a patch source.
    # Raise an exception if invalid.
    #
    # @param days[Integer,String] the name or id of a patch source
    #
    # @return [Integer] the valid id, if in Jamf
    #
    def validate_patch_source(src)
      id = JSS::PatchSource.valid_id src
      raise JSS::NoSuchItemError, "No PatchSource '#{src}' in Jamf Pro" unless id
      id
    end

    def validate_installed_criteria
      raise JSS::MissingDataError, "At least one criterion must be defined for a title's installed_criteria." if installed_criteria.empty?
    end

    def validate_notification(opt)
      opt ||= :none
      opt = opt.to_sym
      raise JSS::InvalidDataError, "Notification must be one of: #{SELF_SVC_NOTIF_OPTIONS.join ', '}" unless SELF_SVC_NOTIF_OPTIONS.include? opt
      opt
    end

    # Set default values and confirm things are ready for saving
    # to the server.
    def validate_for_saving
      validate_description(description)
      case jss_patch_source_id
      when nil
        raise JSS::MissingDataError, 'A patch source is needed for titles not hosted by d3'
      when :d3
        validate_publisher(publisher)
        validate_installed_criteria
      end
    end

  end # class title

end # modle D3
