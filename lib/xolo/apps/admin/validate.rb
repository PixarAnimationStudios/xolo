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

#
module Xolo
  module Admin

    # This module contains methods for validating options given to d3admin
    # either on the commandline or via a walkthru
    #
    # Each method takes an argument, and either raises an exception
    # if the argument isn't valid for its destination, or
    # converts it to the proper type for its destination.
    #
    # For options that set attributes of packages, the appropriate
    # Xolo::Package::Validate method is called.
    #
    # For example, the {#validate_groups} takes either a comma-seprated String
    # or an Array of computer group names, converts the String to an Array
    # if needed, and then confirms that each group exists in the JSS
    # If they all do, the Array is returned.
    #
    module Validate
      extend self

      # Check a value with a given 'validate_' method
      # catching the excpetions and returning error messages
      #
      # @param value[String] the value from the user to check
      #
      # @param validate_method[Symbol] the method to use to check the value
      #
      # @return [Array<Boolean, Object>] A two-item array. The first item
      #   is a Boolean representing the success of failure of the check.
      #   The second item is the validated input, if the check was good,
      #   or the error message if not.
      #
      def validate (value, validate_method)
        return [true, value] unless validate_method
        begin
          valid_value = self.send(validate_method, value)
          return [true, valid_value]
        rescue JSS::InvalidDataError, JSS::NoSuchItemError, JSS::AlreadyExistsError
          return [false, $ERROR_INFO]
        end # begin
      end


      # check that a given pkg id or display name exists in the JSS but not
      # in d3, and if so, return the valid name or id
      #
      # @param pkg_to_check[String] a display name or JSS pkg id
      #
      # @return [Xolo::Package] the unsaved, imported package
      #
      def validate_package_for_import (pkg_to_check)

        # an id, or a name?
        if pkg_to_check.to_s =~ /^\d+$/
          raise JSS::NoSuchItemError, "No package in the JSS with id #{pkg_to_check}" unless JSS::Package.all_ids.include? pkg_to_check.to_i
          raise JSS::AlreadyExistsError, "JSS Package id #{pkg_to_check} is already in d3" if Xolo::Package.all_ids.include? pkg_to_check.to_i
          return pkg_to_check.to_i

        else
          raise JSS::NoSuchItemError, "No package in the JSS with display-name #{pkg_to_check}" unless JSS::Package.all_names.include? pkg_to_check
          raise JSS::AlreadyExistsError, "JSS Package named #{pkg_to_check} is already in d3" if Xolo::Package.all_names.include? pkg_to_check
          return pkg_to_check
        end

      end

      # Check that a given title or patch exists in d3, and if
      # so, return the package id
      # If a title is given, the currently live one is returned
      # If there is no matching patch or live title, an exception is raised
      #
      # @param pkg_to_check[String] a title or patch
      #
      # @return [Xolo::Package] the matching package
      #
      def validate_existing_package (pkg_to_check)
        # were we given an patch?
        pkgid = Xolo::Package.ids_to_patchs.invert[pkg_to_check]
        # if not, were we given a title?
        pkgid ||= Xolo::Package.titles_to_live_ids[pkg_to_check]
        raise JSS::NoSuchItemError, "No patch or live-title in d3 match '#{pkg_to_check}'" if pkgid.nil?

        return pkgid
      end

      # check that the given package name doesn't already exist
      #
      # @see {JSS::Package.validate_package_name}
      #
      def validate_package_name(name)
        Xolo::Package::Validate.validate_package_name name
      end

      # check that the given filename doesn't already exist
      #
      # @param name[String] the name to check
      #
      # @return [String] the valid new file name
      #
      # def self.validate_filename(name)
      def validate_filename(name)
        Xolo::Package::Validate.validate_filename name
      end

      # Check that a title exists, and return it or raise an exception
      #
      # @param title[String]
      #
      # @return [String] the valid title
      def validate_title (title)
        raise JSS::NoSuchItemError, "There's no package in d3 with the title '#{title}'" unless Xolo::Package::Validate.title_exist? title.to_s
        title.to_s
      end

      # Check if an patch exists and raise an exception if so
      # Also check that it contains at least two hyphens
      #
      # @param patch[String] the patch to check
      #
      # @return [String] the valid, unique patch
      #
      def validate_patch (patch)
        Xolo::Package::Validate.validate_patch patch
      end

      # Confirm the validity of a version. Raise an exception if invalid.
      #
      # @param vers[String] the version to check
      #
      # @return [String] An error message, or true if the value is ok
      #
      def validate_version (vers)
        Xolo::Package::Validate.validate_version vers
      end

      # Confirm the validity of a revision.
      # Raise an exception if invalid.
      #
      # @param rev[Integer] the revision to check
      #
      # @return [Integer] the valid revision
      #
      def validate_revision (rev)
        Xolo::Package::Validate.validate_revision rev
      end

      # Check the validity of the local source path
      # Raises an exception if not valid
      #
      # @param src[Pathname, String] the path to check
      #
      # @return [Pathname] the valid, fully-expanded path
      #
      def validate_source_path (src)
        raise JSS::InvalidDataError, "Source path cannot be empty" if src.to_s.empty?
        src = Pathname.new(src.to_s).expand_path
        raise JSS::NoSuchItemError, "'#{src}' doesn't exist" unless src.exist?
        return src if src.to_s.end_with?(".dmg") or src.to_s =~ /\.m?pkg$/

        # isn't a dmg or pkg, check that its a directory to use as a pkg root
        raise JSS::InvalidDataError, "#{src} isn't a .dmg or .pkg, but isn't a folder,\ncan't use it for building packages."  unless  src.directory?
        src
      end

      # check the validity of the pkg build type
      #
      # @param type[String] the string to check
      #
      # @return [Symbol] :pkg or :dmg
      #
      def validate_package_build_type(type)
        case type.to_s.delete('.')
        when /^p/i then :pkg
        when /^d/i then :dmg
        else raise JSS::InvalidDataError, "Package type must be 'pkg', 'dmg', 'p', or 'd'"
        end # case
      end

      # Check the pkg identifier
      #
      # @param pkgid[String]  the identifer
      #
      # @return [String] the valid identifier
      #
      def validate_package_identifier (pkgid)
        raise JSS::InvalidDataError, "Package Identifier must be a String" unless pkgid.is_a? String
        raise JSS::InvalidDataError, "Package Identifier cannot be empty" if pkgid.empty?
        return pkgid
      end

      # Check the pkg identifier prefix
      #
      # @param pfx[String] the prefix for the identifer
      #
      # @return [String] the cleaned-up identifier
      #
      def validate_package_identifier_prefix (pfx)
        return nil if pfx.to_s.empty?
        raise JSS::InvalidDataError, "Package Identifier Prefix must be a String" unless pfx.is_a? String
        return pfx
      end

      ### Validate Signing Identity ?
      def validate_signing_idenitity(id)
        id.is_a?(String) && id
      end

      ### Validate Signing Options
      def validate_signing_options(options)
        options.is_a?(String) && options
      end

      ### Check the path given as a workspace for building pkgs
      ###
      ### @return [Pathname] the valid, full path to the workspace folder
      ###
      def validate_workspace(wkspc)
        wkspc = Pathname.new(wkspc).expand_path
        raise JSS::NoSuchItemError, "Workspace folder '#{wkspc}' doesn't exist" unless wkspc.exist?
        raise JSS::InvalidDataError, "Workspace folder '#{wkspc}' isn't a folder" unless wkspc.directory?
        Xolo::Admin::Prefs.set_pref :workspace, wkspc
        wkspc
      end

      # Check that a report type is valid
      #
      # @return [String] the valid report type.
      #
      def validate_report_type(type)
        raise ArgumentError, "Report type must be one of: #{Xolo::Admin::Report::REPORT_TYPES.join(', ')}" unless Xolo::Admin::Report::REPORT_TYPES.include? type
        type
      end

      # Check that a show type is valid
      #
      # @return [String] the valid show type.
      #
      def validate_show_type(type)
        raise ArgumentError, "Package list must be one of: #{Xolo::Admin::Report::SHOW_TYPES.join(', ')}" unless Xolo::Admin::Report::SHOW_TYPES.include? type
        type
      end

      # @see Xolo::Package::Validate.validate_groups
      def validate_scoped_groups (groups)
        Xolo::Package::Validate.validate_groups groups
      end

      ### check that a computer name  or id exists in jamf
      ###
      ### @param [String,Integer] the name, id, serialnumber, macaaddress, or udid
      ###   of a computer in the JSS
      ###
      ### @return [Integer] the valid computer id
      ###
      def validate_computer(ident)
        id = JSS::Computer.map_all_ids_to(:name).invert[ident]
        id ||= JSS::Computer.map_all_ids_to(:serial_number).invert[ident]
        id ||= JSS::Computer.map_all_ids_to(:mac_address).invert[ident]
        id ||= JSS::Computer.map_all_ids_to(:udid).invert[ident]
        return id if id
        return ident.to_i if JSS::Computer.all_ids.include? ident.to_i
        raise JSS::NoSuchItemError, "No computer in the JSS matches '#{ident}'"
      end

      # Check the validity of a pre_install script
      #
      # @see #validate_script
      #
      def validate_pre_install_script (script)
        Xolo::Package::Validate.validate_script script
      end

      # Check the validity of a post_install script
      #
      # @see #validate_script
      #
      def validate_post_install_script (script)
        Xolo::Package::Validate.validate_script script
      end

      # Check the validity of a pre_remove script
      #
      # @see #validate_script
      #
      def validate_pre_remove_script (script)
        Xolo::Package::Validate.validate_script script
      end

      # Check the validity of a pre_remove script
      #
      # @see #validate_script
      #
      def validate_post_remove_script (script)
        Xolo::Package::Validate.validate_script script
      end

      # @see #validate_groups
      def validate_auto_groups (groups)
        Xolo::Package::Validate.validate_auto_groups groups
      end

      # @see #validate_groups
      def validate_excluded_groups (groups)
        Xolo::Package::Validate.validate_groups groups
      end

      # Make sure auto and excluded groups don't have any
      # members in common, raise an exception if they do.
      #
      # @param auto[Array] the array of auto groups
      #
      # @param excl[Array] the array of excluded groups
      #
      # @return [True] true if there are no groups in common
      #
      def validate_non_overlapping_groups (auto, excl)
        Xolo::Package::Validate.validate_non_overlapping_groups auto, excl
      end

      # Check the validity of a list of OSes
      # Raise an exception if not valid
      #
      # @param [String,Array] Array or comma-separated list of OSes to check
      #
      # @return [Array] the valid OS list
      #
      def validate_oses (os_list)
        Xolo::Package::Validate.validate_oses os_list
      end

      # Check the validity of a CPU type
      # Raise an exception if not valid
      #
      # @param [Symbol] the CPU type to check
      #
      # @return [Symbol] the valid CPU type
      #
      def validate_cpu_type (type)
        Xolo::Package::Validate.validate_cpu_type type
      end

      # Check the validity of a category
      # Raise an exception if not valid
      #
      # @param cat[String] the category to check
      #
      # @return [String] the valid category
      #
      def validate_category (cat)
        Xolo::Package::Validate.validate_category cat
      end

      # Check multiple prohibiting_processes for validity
      #
      # @param process_names[String,Array<String>] A comma-separated String, or an Array of process names to be validated.
      #
      # @return [Array<String>]
      #
      def validate_prohibiting_processes (process_names)
        process_names = [] if process_names.to_s =~ /^n(one)?$/i
        names_as_array = JSS.to_s_and_a(process_names)[:arrayform]
        names_as_array.map { |procname| Xolo::Package::Validate.validate_prohibiting_process(procname) }.compact
      end

      # check the validity of a yes/no true/false reply
      #
      # @param type[String,Boolean] the value to check
      #
      # @return [Boolean]
      #
      def validate_yes_no (yn)
        Xolo::Package::Validate.validate_yes_no yn
      end

      # Confirm the validity of an expiration.
      # Raise an exception if invalid.
      #
      # @param exp[Integer] the expiration to check
      #
      # @return [Integer] the valid expiration
      #
      def validate_expiration (exp)
        Xolo::Package::Validate.validate_expiration exp
      end

      # Confirm the validity of one or more expiration paths.
      # Any string that starts with a / is valid.
      # The strings "n" or "none" returns an empty array.
      #
      # @param paths[Pathname, String, Array<String,Pathname>] the path(s) to check
      #
      # @return [Array<Pathname>] the valid path
      #
      def validate_expiration_bundle_ids (paths)
        Xolo::Package::Validate.validate_expiration_bundle_ids paths
      end

      # Confirm the validity of an expiration path.
      # any string that starts with a / is valid.
      #
      # @param path[Pathname, String] the path to check
      #
      # @return [Pathname, nil] the valid path
      #
      def validate_expiration_path (path)
        Xolo::Package::Validate.validate_expiration_path path
      end


    end # module Validate
  end # module Admin
end # module Xolo
