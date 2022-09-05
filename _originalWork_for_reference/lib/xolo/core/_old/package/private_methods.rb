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

    ############### Private Instance Methods #################
    private

    # Is there a process running that would prevent installation?
    #
    # @return [Boolean]
    #
    def install_prohibited_by_process?
      return false unless @prohibiting_processes
      return false if @prohibiting_processes.empty?
      Xolo.prohibited_by_process_running? @prohibiting_processes
    end #

    # If needed, uninstall any previously installed versions of this title
    #
    def remove_previous_installs_if_needed (verbose = false)
      if @remove_first && Xolo::Client::Receipt.titles.include?(@title)
        previous_rcpt = Xolo::Client::Receipt.all[@title]
        if previous_rcpt.removable?
          Xolo.log "Uninstalling previously installed version of #{@title}" , :info
          begin
            Xolo::Client.set_env :uninstalling_before_install, previous_rcpt.patch
            previous_rcpt.uninstall(verbose)
          ensure
            Xolo::Client.unset_env :uninstalling_before_install
          end # begin
        else
          Xolo.log "Previously installed version of #{@title} is not uninstallable, not uninstalling.", :info
        end # if previous_rcpt.removable?
      end # @remove_first && Xolo::Client::Receipt.titles
    end # remove_previous_installs_if_needed

    # Create a new D3 receipt for this pkg and store it in the
    # receipts datastore.
    #
    # @return [void]
    #
    def write_rcpt
        new_rcpt =  Xolo::Client::Receipt.new( :title => @title,
            :version => @version,
            :revision => @revision,
            :admin => @admin,
            :installed_at => Time.now,
            :id => @id,
            :status => @status,
            :jamf_rcpt_file => @receipt,
            :apple_pkg_ids => @apple_receipt_data.map{|r| r[:apple_pkg_id]},
            :removable => removable?,
            :pre_remove_script_id => @pre_remove_script_id,
            :post_remove_script_id => @post_remove_script_id,
            :expiration => @expiration_to_apply.to_i,
            :expiration_bundle_ids => @expiration_bundle_ids,
            :custom_expiration => @custom_expiration,
            :prohibiting_processes => @prohibiting_processes)

        Xolo::Client::Receipt.add_receipt new_rcpt, :replace

    end # write_rcpt

    # Dump this pkg as a YAML marshalled string, for archiving
    #
    # @reutrn [String] the YAML representation of this pkg
    #
    def package_yaml
      YAML.dump self
    end

    def added_by= (name)
      @added_by = name
    end

    def added_date= (date)
      @added_date = date
    end

    def released_by= (name)
      @released_by = name
    end

    def release_date= (date)
      @release_date = date
    end

    def apple_receipt_data= (data)
      @apple_receipt_data = data
    end

    # Given one of the keys of the Xolo::Database::PACKAGE_TABLE[:field_definitions] hash,
    # convert the matching attribute value with the :to_sql Proc and return it.
    # If there is no matching attribute, assume the argument is a value
    # and return it Mysql.quoted.
    #
    # @param key[Symbol] the attribute to convert to SQL
    #
    # @return [String] the attribute value converted to an SQL-happy format
    #
    def to_sql(key)
      if key.is_a?(Symbol) and self.respond_to?(key)
        return 'NULL' if self.send(key).to_s.empty?
        if P_FIELDS[key] and P_FIELDS[key][:to_sql]
          return Mysql.quote(P_FIELDS[key][:to_sql].call(self.send(key)).to_s)
        else
          return Mysql.quote(self.send(key).to_s)
        end # if P_FIELDS[key] and P_FIELDS[key][:to_sql]
      else
        return Mysql.quote(key.to_s)
      end #  if key.is_a?(Symbol)
    end # to_sql(key)

    # Given one of the keys of the Xolo::Database::PACKAGE_TABLE[:field_definitions] hash,
    # and a value from an SQL query, convert the SQL value to the appropriate Ruby value
    # with the :to_ruby Proc and return it
    #
    # @param key[Symbol] the attribute to convert to SQL
    #
    # @return [Object] the attribute value converted to an SQL-happy format
    #
    def to_ruby(key, sql_val)
      # Note = the d3pkgdata has already been 'rubyized' via the Xolo::Database.table_records method
      # (which was used by Xolo::Package.package_data)
      return sql_val unless P_FIELDS[key][:to_ruby]
      return P_FIELDS[key][:to_ruby].call(sql_val)
    end

    # Make this package not live, which could be described as killing it, but
    # I think it would be more like 'zombification',
    # leaving no pkg live for this title
    #
    # @return [void]
    #
    def deprecate(admin = @admin)

      raise JSS::InvalidDataError, "Only live packages can be deprecated." unless @status == :live
      @status = :deprecated
      stmt = JSS::DB_CNX.db.prepare "UPDATE #{P_TABLE[:table_name]} SET #{P_FIELDS[:status][:field_name]} = #{to_sql :status} WHERE #{P_FIELDS[:id][:field_name]} = '#{@id}'"

      stmt_result = stmt.execute

      # update our knowledge of the world
      Xolo::Package.package_data :refresh

      @status
    end

    # Delete any scripts associated with this pkg
    # but only if they aren't associated with other d3 pkgs or casper policies
    #
    # @return [Array<String>] a textual list of scripts and whether they were
    #   deleted or not (and why not)
    #
    def delete_pkg_scripts

      # gather the ids of all scripts used by all policies
      # this is a hash of arrays  pol_name => [id,id,id]
      policy_scripts = Xolo.policy_scripts

      script_deletion_actions = []

      scripts = [:pre_install_id , :post_install_id , :pre_remove_id , :post_remove_id ]

      scripts.each do |script_type|

        type_display = script_type.to_s.chomp('_id')

        victim_script_id = self.send script_type
        victim_script_name = JSS::Script.map_all_ids_to(:name)[victim_script_id]

        # skip if not in jss
        next unless JSS::Script.all_ids.include? victim_script_id

        # these d3 pkg patchs use this script
        d3_users = (Xolo::Package.packages_for_script(victim_script_id) - [@id])
        d3_users.map!{|pkgid| Xolo::Package.ids_to_patchs[pkgid]}

        # these policies use this script
        policy_users = []
        policy_scripts.each do |pol, pol_scripts|
          policy_users << pol if pol_scripts.include? victim_script_id
        end

        if d3_users.empty? and policy_users.empty?
          # delete the script!
          JSS::Script.new(id: victim_script_id).delete
          script_deletion_actions << "deleted #{type_display} script '#{victim_script_name}'"
        else
          # add the info to the returned report
          d3_users.each {|patch| script_deletion_actions << "#{type_display} script '#{victim_script_name}' is in use by d3 package: #{patch}"}
          policy_users.each {|pol_name| script_deletion_actions << "#{type_display} script '#{victim_script_name}' is in use by policy: #{pol_name}"}
        end # if both empty

      end # scripts.each do |script_type|

      return script_deletion_actions

    end # delete_scripts



  end # class Package
end # module Xolo
