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
  class Package < JSS::Package

    ############### Public Instance Methods #################

    # Set the login name of the admin who's doing something with this pkg
    #
    # @param new_val[String] the name of the admin
    #
    # @return [void]
    #
    def admin= (new_val = @admin)
      return nil if new_val == @admin
      raise "admin can't be empty!" if new_val.to_s == ''
      @admin = new_val
    end

    # Set the title of this package
    #
    # new_val = string
    #
    def title= (new_val = @title)
      return nil if new_val == @title
      validate_patch "#{new_val}-#{@version}-#{@revision}"
      @title = new_val.to_s
      @need_to_update_d3 = true unless @initializing
    end

    # Set the version of this package
    #
    # new_val = string
    #
    def version= (new_val = @version)
      return nil if new_val == @version
      new_val = validate_version new_val
      validate_patch "#{title}-#{new_val}-#{@revision}"
      @version = new_val
      @need_to_update_d3 = true unless @initializing
    end

    # Set the title of this package
    #
    # new_val = string
    #
    def revision= (new_val = @revision)
      return nil if new_val == @revision
      new_val = validate_revision new_val
      validate_patch "#{title}-#{@version}-#{new_val}"
      @revision = new_val
      @need_to_update_d3 = true unless @initializing
    end

    # Set whether or not this package should uninstall other
    # installed versions before installing itself. Otherwise,
    # it'll just install itself over whatever's already there.
    #
    # @param new_val[Boolean] Should d3 uninstall other versions before installing self
    #
    # @return [void]
    #
    def remove_first= (new_val = @remove_first)
      new_val ||= false # nil defaults to false
      return new_val if new_val == @remove_first
      @remove_first = validate_yes_no new_val
      @need_to_update_d3 = true unless @initializing
    end

    # Set the expiration period for all installs of this pkg.
    # Once installed, if this many days go by without
    # the @expiration_bundle_ids being launched, as noted by d3repoman, the pkg
    # will be silently uninstalled.
    #
    # Use nil, false, or 0 (the default) to prevent expiration.
    #
    # When expiration happens, a policy can be triggered to notify the user or
    # take other actions. See {Xolo::Client#expiration_policy}
    #
    # Can be over-ridden on a per-install basis using the
    # :expiration option with the {#install} method
    #
    # @param new_val[Integer] The number of days with no launch before expiring.
    #
    # @return [void]
    #
    def expiration= (new_val = @expiration)
      return @expiration if new_val == @expiration
      new_val ||= 0
      @expiration = validate_expiration(new_val)
      @need_to_update_d3 = true unless  @initializing
    end # expiration =

    # Set the expiration paths for this pkg.
    # These are abosulute paths to executables one of which must be brought to the
    # foreground at least once every @expiration days to prevent
    # silent un-installing of this package.
    #
    # The paths are those recorded in d3RepoMan's timestamp plists.
    # @example "/Applications/FileMaker Pro 11/FileMaker Pro.app/Contents/MacOS/Filemaker Pro"
    #
    # @param new_val[String,Pathname,Array<String,Pathname>] The expiration paths.
    #   A Pathname for a single path, a String for single, or multiple
    #   (comma-separated) or an Array of Strings or Pathnames for single paths.
    #   Each path must be an absolute path starting with a /
    #
    # @return [void]
    #
    def expiration_bundle_ids= (new_val = @expiration_bundle_ids)
      return @expiration_bundle_ids if Xolo::Admin::OPTIONS[:expiration_bundle_ids][:compare].call(@expiration_bundle_ids, new_val)
      @expiration_bundle_ids = validate_expiration_bundle_ids (new_val)
      @need_to_update_d3 = true unless @initializing
    end # expiration =

    # Add a path to expiration_bundle_ids
    # @param new_val[String,Pathname]
    #
    # The paths are those recorded in d3RepoMan's timestamp plists.
    # @example "/Applications/FileMaker Pro 11/FileMaker Pro.app/Contents/MacOS/Filemaker Pro"
    #
    def add_expiration_path (path)
      path = validate_expiration_path(path)
      @expiration_bundle_ids << path
      @need_to_update_d3 = true unless @initializing
    end # add_expiration_path

    # Remove a path from expiration_bundle_ids
    # @param new_val[String,Pathname]
    #
    # The paths are those recorded in d3RepoMan's timestamp plists.
    # @example "/Applications/FileMaker Pro 11/FileMaker Pro.app/Contents/MacOS/Filemaker Pro"
    #
    def remove_expiration_path (path)
      @expiration_bundle_ids.delete Pathname.new(path)
      @need_to_update_d3 = true unless @initializing
    end # remove_expiration_path


    # Set the prohibiting processes for this installer.
    #
    # The value of this attribute is compared at install time to the lines output
    # by the command 'ps -A -c -o comm' (case insensitive)
    #
    # If any line matches, d3 will attempt to quit the process (or prompt the user
    # to quit the Application) to proceed with installation.
    #
    # @param new_val[Array<String>] the process name(s) that should not be running during installation.
    #
    # @return [void]
    #
    def prohibiting_processes= (new_val = @prohibiting_processes)
      new_val = JSS.to_s_and_a(new_val)[:arrayform]
      return @prohibiting_processes if Xolo::Admin::OPTIONS[:prohibiting_processes][:compare].call(@prohibiting_processes, new_val)
      @prohibiting_processes = new_val.each {|process| validate_prohibiting_process process}
      @need_to_update_d3 = true unless @initializing
    end

    # Set the automatic-install groups for this package.
    # See also {#add_auto_group} and {#remove_auto_group}
    #
    # @param new_val[String,Array<String>] The group names as a comma-separated string or an array of strings
    #
    # @return [void]
    #
    def auto_groups= (new_val = @auto_groups)
      @auto_groups ||= []
      new_val ||= []
      return @auto_groups if Xolo::Admin::OPTIONS[:auto_groups][:compare].call(@auto_groups, new_val)
      new_groups = validate_auto_groups (new_val)
      validate_non_overlapping_groups new_groups, @excluded_groups
      @auto_groups =  new_groups
      @need_to_update_d3 = true unless @initializing
    end

    # Add one or more groups the to list of auto_groups.
    # The arg is a comma-separated string or an array of
    # group names.
    #
    # @param groupnames[String, Array] the names of the groups to add
    #
    # @return [void]
    #
    def add_auto_groups (groupnames)
      # are they real groups?
      new_groups = validate_groups(groupnames)
      # if they're already there, just return
      return @auto_groups if (@auto_groups & new_groups) == new_groups
      validate_non_overlapping_groups new_groups, @excluded_groups
      @auto_groups += new_groups
      @need_to_update_d3 = true unless @initializing
    end

    # Remove one or more groups the to list of auto_groups.
    # The arg is a comma-separated string or an array of
    # group names.
    #
    # @param groupnames[String, Array] the names of the groups to remove
    #
    # @return [void]
    #
    def remove_auto_groups (groupnames)
      remove_groups = JSS.to_s_and_a(groupnames)[:arrayform]
      @auto_groups -= remove_groups
      @need_to_update_d3 = true unless @initializing
    end

    # Set the excluded groups for this package.
    # See also {#add_excluded_group} and {#remove_excluded_group}
    #
    # @param new_val [String,Array<String>] The group names as a comma-separated string or an array of strings
    #
    # @return [void]
    #
    def excluded_groups= (new_val = @excluded_groups)
      @excluded_groups ||= []
      new_val ||= []
      new_groups = validate_auto_groups (new_val)
      return @excluded_groups if Xolo::Admin::OPTIONS[:excluded_groups][:compare].call(@excluded_groups, new_val)
     validate_non_overlapping_groups @auto_groups, new_groups
      @excluded_groups =  new_groups
      @need_to_update_d3 = true unless @initializing
    end

    # Add one or more groups the to list of excluded_groups.
    # The arg is a comma-separated string or an array of
    # group names.
    #
    # @param groupnames[String, Array] the names of the groups to add
    #
    # @return [void]
    #
    def add_excluded_groups (groupnames)
      # are they real groups?
      new_groups = validate_groups(groupnames)
      # if they're already there, just return
      return @excluded_groups if (@excluded_groups &  new_groups) == new_groups
      validate_non_overlapping_groups new_groups, @auto_groups
      @excluded_groups += new_groups
      @need_to_update_d3 = true unless @initializing
    end

    # Remove one or more groups the to list of excluded_groups.
    # The arg is a comma-separated string or an array of
    # group names.
    #
    # @param groupnames[String, Array] the names of the groups to remove
    #
    # @return [void]
    #
    def remove_excluded_groups (groupnames)
      remove_groups = JSS.to_s_and_a(groupnames)[:arrayform]
      @excluded_groups -= remove_groups
      @need_to_update_d3 = true unless @initializing
    end

    # Set the pre_install_script for this package, either by name or JSS id,
    # or a Path (String or Pathname) to a local file.
    #
    # The script must exist in the JSS or the local file must exist
    #
    # @param new_val[String,Integer] the path, name or id of the JSS::Script to use
    #
    # @return [void]
    #
    def pre_install= (new_val = @pre_install_script_id)
      name_or_path = validate_pre_install_script(new_val)
      if name_or_path.is_a?(Pathname)
        @pre_install_script_id = new_script script_type: :pre_install, source: name_or_path
      else
        @pre_install_script_id = JSS::Script.map_all_ids_to(:name).invert[name_or_path]
      end
      @need_to_update_d3 = true unless @initializing
    end

    # Set the post_install_script for this package, either by name or JSS id,
    # or a Path (String or Pathname) to a local file.
    #
    # The script must exist in the JSS or the local file must exist
    #
    # @param new_val[String,Integer] the name or id of the JSS::Script to use
    #
    # @return [void]
    #
    def post_install= (new_val = @post_install_script_id)
      name_or_path = validate_post_install_script(new_val)
      if name_or_path.is_a?(Pathname)
        @post_install_script_id = new_script script_type: :post_install, source: name_or_path
      else
        @post_install_script_id = JSS::Script.map_all_ids_to(:name).invert[name_or_path]
      end
      @need_to_update_d3 = true unless @initializing
    end

    # Set the pre_remove_script for this package, either by name or JSS id,
    # or a Path (String or Pathname) to a local file.
    #
    # The script must exist in the JSS or the local file must exist
    #
    # @param new_val[String,Integer] the name or id of the JSS::Script to use
    #
    # @return [void]
    #
    def pre_remove= (new_val = @pre_remove_script_id)
      name_or_path = validate_pre_remove_script(new_val)
      if name_or_path.is_a?(Pathname)
        @pre_remove_script_id = new_script script_type: :pre_remove, source: name_or_path
      else
        @pre_remove_script_id = JSS::Script.map_all_ids_to(:name).invert[name_or_path]
      end
      @need_to_update_d3 = true unless @initializing
    end

    # Set the post_remove_script for this package, either by name or JSS id,
    # or a Path (String or Pathname) to a local file.
    #
    # The script must exist in the JSS or the local file must exist
    #
    # @param new_val[String,Integer] the name or id of the JSS::Script to use
    #
    # @return [void]
    #
    def post_remove= (new_val = @post_remove_script_id)
      name_or_path = validate_post_remove_script(new_val)
      if name_or_path.is_a?(Pathname)
        @post_remove_script_id = new_script script_type: :post_remove, source: name_or_path
      else
        @post_remove_script_id = JSS::Script.map_all_ids_to(:name).invert[name_or_path]
      end
      @need_to_update_d3 = true unless @initializing
    end


  end # class Package
end # module Xolo
