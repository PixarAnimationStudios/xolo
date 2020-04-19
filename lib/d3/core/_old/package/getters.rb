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
module D3
  class Package < JSS::Package

    # @return [String,nil] - The name of the pre-install script for this pkg, or nil if none
    #
    def pre_install_script_name
      return nil unless @pre_install_script_id
      JSS::Script.map_all_ids_to(:name)[@pre_install_script_id]
    end

    # @return [String,nil] - The name of the post install script for this pkg, or nil if none
    #
    def post_install_script_name
      return nil unless @post_install_script_id
      JSS::Script.map_all_ids_to(:name)[@post_install_script_id]
    end

    # @return [String,nil] - The name of the pre remove script for this pkg, or nil if none
    #
    def pre_remove_script_name
      return nil unless @pre_remove_script_id
      JSS::Script.map_all_ids_to(:name)[@pre_remove_script_id]
    end

    # @return [String,nil] - The name of the post remove script for this pkg, or nil if none
    #
    def post_remove_script_name
      return nil unless @post_remove_script_id
      JSS::Script.map_all_ids_to(:name)[@post_remove_script_id]
    end

    # @return [Hash{Symbol=>Integer}] The type and ids of all pre- and post- scripts
    #   for this pkg.
    def script_ids
      {
        :pre_install => @pre_install_script_id,
        :post_install => @post_install_script_id,
        :pre_remove => @pre_remove_script_id,
        :post_remove => @post_remove_script_id
      }
    end

    # @return [Hash{Symbol=>String}] The type and names of all pre- and post- scripts
    #   for this pkg.
    def script_names
      {
        :pre_install => @pre_install_script_name,
        :post_install => @post_install_script_name,
        :pre_remove => @pre_remove_script_name,
        :post_remove => @post_remove_script_name
      }
    end

    def minimum_os_for_patch
      os = os_requirements.first.to_s
      os.sub /.x$/, '.0'
    end

    # Generate a human-readable string of details about this installer
    #
    # @return [String] the package details in a human readble format.
    #
    def formatted_details
      os_disp = JSS.to_s_and_a(@os_requirements)[:stringform]
      auto_disp = JSS.to_s_and_a(@auto_groups)[:stringform]
      excl_disp = JSS.to_s_and_a(@excluded_groups)[:stringform]

      msg = <<-END_DEETS
patch: #{patch}
Status: #{@status}
---- Description ----
#{@notes.gsub("\r", "\n") if @notes}
---------------------
Added by: #{@added_by or 'unknown'}
Added date: #{@added_date ? @added_date.strftime('%Y-%m-%d') : 'unknown'}
Casper Package: #{@name} (id: #{@id})
Filename: #{@filename}
Category: #{@category or 'None'}
Needs reboot (puppytime): #{@reboot_required or 'false'}
Un-installable: #{removable? or 'false'}
Pre-install script: #{pre_install_script_name or 'None'}
Post-install script: #{post_install_script_name or 'None'}
Pre-remove script: #{pre_remove_script_name or 'None'}
Post-remove script: #{post_remove_script_name or 'None'}
CPU limitation: #{@required_processor or 'None'}
OS limitations: #{os_disp.empty? ? 'None' : os_disp}
Uninstalls older versions: #{@remove_first or 'false'}
Installation prohibited by process(es): #{D3::Admin::OPTIONS[:prohibiting_processes][:display_conversion].call @prohibiting_processes or 'None'}
Auto installed for groups: #{auto_disp.empty? ? 'None' : auto_disp}
Excluded for groups: #{excl_disp.empty? ? 'None' : excl_disp}
Expiration period: #{@expiration.to_i} days
Expiration path(s): #{D3::Admin::OPTIONS[:expiration_bundle_ids][:display_conversion].call @expiration_bundle_ids}
Released by: #{@released_by or '-'}
Release date: #{@release_date ? @release_date.strftime('%Y-%m-%d') : '-'}
      END_DEETS
    end #formatted_details

    # The index of this package
    # This is an array of paths (as Strings) from the pkg's Casper index
    #
    # @param files_only[Boolean] ignore directories, only return files
    #
    # @return [Array<String>]
    #
    def index (files_only = false)
      q =  "SELECT file FROM #{PKG_CONTENTS_TABLE} WHERE package_id = #{@id}"
      q += " AND mode NOT LIKE 'd%'" if files_only
      @index = []
      JSS::DB_CNX.db.query(q).each {|record| @index << record[0]}
      @index
    end

    # Get an array of files installed by this pkg
    # Note that this does not show directories.
    # use #index to see dirs as well
    #
    # @return [Array<Pathname>] the files installed
    #
    def installed_files
      index :files_only
    end

    # An Array of ids of all Casper policies using this package
    #
    # @return [Array<Integer>] the policy ids using this package.
    #
    def policy_ids
      qry = <<-ENDQ
      SELECT p.policy_id
      FROM policies p
      JOIN policy_packages pp
        ON p.policy_id = pp.policy_id
      WHERE pp.package_id = '#{@id}'
      ENDQ
      res = JSS::DB_CNX.db.query qry
      pols = []
      res.each{|r| pols << r[0].to_i }
      res.free
      pols
    end


  end # class Package
end # module D3
