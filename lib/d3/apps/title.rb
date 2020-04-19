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

module D3

  # Title methods & values specific to the d3 client tools d3 and d3admin
  #
  class Title < AbstractTitle

    # Constants
    ##############################

    LIST_RSRC = 'titles'.freeze

    OBJECT_RSRC = "#{LIST_RSRC}/".freeze

    # Class Methods
    ##############################

    # A an array of Hashes, summary data for all titles
    #
    def self.all(*attribs)
      attribs.empty? ? D3.cnx.get(LIST_RSRC) : D3.cnx.get("#{LIST_RSRC}/?fields=#{attribs.join ','}")
    end

    # @return [Array<String>] the names of all titles in d3
    #
    def self.all_names
      all.map { |t| t[:name] }
    end

    def self.exist?(name)
      all_names.include? name
    end

    # Fetch an existing title from the d3 server by name
    def self.fetch(name)
      validate_title_exists name
      new from_json: D3.cnx.get(OBJECT_RSRC + name)
    end

    def self.delete(name)
      validate_title_exists name
      D3.cnx.delete(OBJECT_RSRC + name)
    end

    # Version summary data for all versions for a given title
    #
    # @return [Array<Hash>]
    #
    def self.versions(name)
      validate_title_exists name
      D3::Version.all.select { |v| v[:title] == name }
    end

    # Version strings for all versions for a given title
    #
    # @return [Array<String>]
    #
    def self.version_strings(name)
      versions(name).map { |v| v[:version] }
    end

    # The changelog for this title. An array of hashes
    # each with 3 keys:
    #   timestamp: [Time] when the change was made
    #   admin: [String] the name of the admin who made the change
    #   msg:  [String] the textual description of the change.
    #
    # Changes to versions are recorded in the changelog for their title.
    #
    # @param name[String] the unique name of a title.
    # @return [Hash{Time => Hash]
    #
    def self.changelog(name)
      validate_title_exists name
      log_from_json = D3.cnx.get "#{OBJECT_RSRC}#{name}/changelog"
      # change the keys back into Times
      log_from_json.each { |change| change[:timestamp] = Time.parse change[:timestamp] }
    end

    # Instance Methods
    #################################

    #### GETTERS (most are defined in AbstractTitle)

    # @return [String] the contents of the autopkg_recipe for this title
    #
    def autopkg_recipe_contents
      # TODO: Implement server route to get this on demand
    end

    def pilot_groups
      group_names :pilot
    end

    def auto_groups
      group_names :auto
    end

    def excluded_groups
      group_names :excl
    end

    def versions
      self.class.versions name
    end

    def version_strings
      self.class.version_strings name
    end

    def changelog
      self.class.changelog(name)
    end

    #### SETTERS

    # All single-value setters do their work here, after data validation.
    # This not only updates the attr value but records the
    # change to be logged on the server in the title's changelog
    def update_attr(attr, newval)
      startval = send(attr)
      instance_variable_set "@#{attr}", newval
      note_in_changes attr, startval, newval
    end

    # update the changelog for an attribute
    # deleting the entry if the new value is the
    # same as what we first noted.
    # This means any number of changes will be
    # ignored if there's no net change.
    def note_in_changes(attr, startval, endval)
      @changes[attr] ||= {}
      @changes[attr][:orig] ||= startval
      # if endval == orig, then there have been no net
      # changes so remove the entry form the changelog
      if @changes[attr][:orig] == endval
        @changes.delete attr
      else
        @changes[attr][:new] = endval
      end
    end

    # Attributes of titles NOT hosted by d3
    #################

    # @param newid[Integer, String] the name or id of the JSS::PatchSource that holds this title.
    #
    def jss_patch_source=(newsource)
      src_id = validate_patch_source newsource
      return if src_id == @jss_patch_source_id
      update_attr :jss_patch_source_id, src_id
    end

    def autopkg_recipe=(new_recipe)
      JSS::Validate.non_empty_string new_recipe
      return if new_recipe == @autopkg_recipe
      update_attr :autopkg_recipe, new_recipe
    end

    def autopkg_recipe_contents=(new_recipe)
      # TODO: Implement server route to set this on demand
    end

    # Attributes of titles hosted by d3
    #################

    def publisher=(pub)
      pub = validate_publisher(pub)
      return if pub == publisher
      update_attr :publisher, pub
    end

    # setters for the installed criteria are
    # in the D3::Criteria object stored in
    # @installed_criteria

    # @param new_ea[D3::ExtensionAttribute]
    #
    def add_ext_attr(new_ea)
      raise ArgumentError, 'Parameter must be a D3::ExtensionAttribute object' unless new_ea.is_a? D3::ExtensionAttribute

      start_eanames = @extension_attributes.map(&:name).sort
      return if start_eanames.include? new_ea.name

      @extension_attributes << new_ea
      new_eanames = @extension_attributes.map(&:name).sort
      note_in_changes :ext_attrs, start_eanames.join(','), new_eanames.join(',')
    end

    # @param ea_name[String] the name of the ea to remove
    #
    def remove_ext_attr(ea_name)
      start_eanames = @extension_attributes.map(&:name).sort
      return unless start_eanames.include? ea_name

      @extension_attributes.delete_if { |ea| ea.name == ea_name }
      new_eanames = @extension_attributes.map(&:name).sort
      note_in_changes :ext_attrs, start_eanames.join(','), new_eanames.join(',')
    end

    # Attributes of all titles
    #################

    def description=(desc)
      desc = validate_description(desc)
      return if desc == description
      update_attr :description, desc
    end

    def category=(cat)
      cat = nil if cat.to_s.empty?
      validate_category(cat)
      return if cat == category
      update_attr :category, cat
    end

    ### Scoping

    # Set the pilot_groups groups for this title.
    # See also {#add_pilot_groups} and {#remove_pilot_groups}
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def pilot_groups=(*groups)
      groups.flatten!
      groups.map! { |g| validate_pilot_group g } # converts names to ids
      groups.sort!
      return if groups == pilot_group_ids.sort
      update_attr :pilot_group_ids, groups
    end

    # Add one or more groups to the list of auto_groups.
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def add_pilot_groups(*groups)
      groups.flatten!
      groups.map! { |g| validate_pilot_group g } # converts names to ids
      new_groups = (groups + piloto_group_ids).uniq
      new_groups.sort!
      return if new_groups == pilot_group_ids.sort
      update_attr :pilot_group_ids, new_groups
    end

    # Remove one or more groups from the list of auto_groups.
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def remove_pilot_groups(*groups)
      groups.flatten!
      current_groups = D3.computer_groups
      groups.map! { |g| current_groups[g] }
      new_groups = (pilot_group_ids - groups.compact)
      new_groups.sort!
      return if new_groups == pilot_group_ids.sort
      update_attr :pilot_group_ids, new_groups
    end

    # Make this title auto-install on all non-excluded machines
    # and empoes the auto-group list.
    def make_standard
      return if standard?
      update_attr :standard, true
      update_attr :auto_group_ids, []
    end

    # Stop this title from auto-installing on all non-excluded machines
    #
    def make_non_standard
      return unless standard?
      update_attr :standard, false
    end

    # Set the auto-install groups for this title.
    # See also {#add_auto_groups} and {#remove_auto_groups}
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def auto_groups=(*groups)
      groups.flatten!
      groups.map! { |g| validate_auto_group g } # converts names to ids
      groups.sort!
      return if groups == auto_group_ids.sort
      update_attr :auto_group_ids, groups
    end

    # Add one or more groups to the list of auto_groups.
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def add_auto_groups(*groups)
      groups.flatten!
      groups.map! { |g| validate_auto_group g } # converts names to ids
      new_groups = (groups + auto_group_ids).uniq
      new_groups.sort!
      return if new_groups == auto_group_ids.sort
      update_attr :auto_group_ids, new_groups
    end

    # Remove one or more groups from the list of auto_groups.
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def remove_auto_groups(*groups)
      groups.flatten!
      current_groups = D3.computer_groups
      groups.map! { |g| current_groups[g] }
      new_groups = (auto_group_ids - groups.compact)
      new_groups.sort!
      return if new_groups == auto_group_ids.sort
      update_attr :auto_group_ids, new_groups
    end

    # Set the excluded groups for this title.
    # See also {#add_excluded_groups} and {#remove_excluded_groups}
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def excluded_groups=(*groups)
      groups.flatten!
      groups.map! { |g| validate_excluded_group g } # converts names to ids
      groups.sort!
      return if groups == excluded_group_ids.sort
      update_attr :excluded_group_ids, groups
    end

    # Add one or more groups to the list of excluded_groups.
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def add_excluded_groups(*groups)
      groups.flatten!
      groups.map! { |g| validate_excluded_group g } # converts names to ids
      new_groups = (groups + excluded_group_ids).uniq
      new_groups.sort!
      return if new_groups == excluded_group_ids.sort
      update_attr :excluded_group_ids, new_groups
    end

    # Remove one or more groups from the list of auto_groups.
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def remove_excluded_groups(*groups)
      groups.flatten!
      current_groups = D3.computer_groups
      groups.map! { |g| current_groups[g] }
      new_groups = (excluded_group_ids - groups.compact)
      new_groups.sort!
      return if new_groups == excluded_group_ids.sort
      update_attr :excluded_group_ids, new_groups
    end

    ### Expiration

    # Set the expiration period for all installs of this pkg.
    # Once installed, if this many days go by without
    # the @expiration_bundle_ids being in the foreground, as noted by d3repoman,
    # the pkg will be silently uninstalled.
    #
    # Use nil, false, or an integer less than 1 to prevent expiration.
    #
    # When expiration happens, a policy can be triggered to notify the user or
    # take other actions. See {D3::Client#expiration_policy}
    #
    # Can be over-ridden on a per-install basis using the
    # :expiration option with the {#install} method
    #
    # @param days[Integer] The number of days with no launch before expiring.
    #
    # @return [void]
    #
    def expiration=(days)
      days = validate_expiration days
      return if days == expiration
      update_attr :expiration, days
    end

    # Set the expiration bundle ids for this pkg.
    # These are .app bundle ids, e.g. com.mycompany.myapp
    # one of which must be brought to the
    # foreground at least once every @expiration days to prevent
    # silent un-installing of this package.
    #
    # @param ids [String,Array<String>] The expiration bundle ids.
    #
    # @return [void]
    #
    def expiration_bundle_ids=(*ids)
      ids.flatten!
      ids.map! { |id| validate_expiration_bundle_id id }
      return if ids.sort == expiration_bundle_ids.sort
      update_attr :expiration_bundle_ids, ids
    end # expiration =

    # Add an id to expiration_bundle_ids. See {#expiration_bundle_ids=}
    #
    # @param new_val[String]
    #
    # @return [void]
    #
    def add_expiration_bundle_id(id)
      id = validate_expiration_bundle_id(id)
      return if expiration_bundle_ids.include? id
      new_ids = expiration_bundle_ids + [id]
      update_attr :expiration_bundle_ids, new_ids
    end # add_expiration_path

    # Remove a path from expiration_bundle_ids. See {#expiration_bundle_ids=}
    #
    # @param new_val[String,Pathname]
    #
    # @return [void]
    #
    def remove_expiration_bundle_id(id)
      return unless expiration_bundle_ids.include? id
      new_ids = expiration_bundle_ids - [id]
      update_attr :expiration_bundle_ids, new_ids
    end # remove_expiration_path

    ### Self Service

    def show_in_self_service
      return if @in_self_service
      update_attr :in_self_service, true
    end

    def remove_from_self_service
      return unless @in_self_service
      update_attr :in_self_service, false
    end

    def display_name=(newname)
      newname = validate_display_name newname
      return if newname == @display_name
      update_attr :display_name, newname
    end

    def notify=(opt)
      opt = validate_notification opt
      return if opt == @notify
      update_attr :notify, opt
    end

    # This is always reset to false
    # after saving changes, isn't
    # part of the change log
    def resend_notifications
      @resend = true
    end

    def feature_in_ssvc_main
      update_attr :feature, true
    end

    def dont_feature_in_ssvc_main
      update_attr :feature, false
    end

    # Set the excluded groups for this title.
    # See also {#add_excluded_groups} and {#remove_excluded_groups}
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def feature_categories=(*cats)
      cats.flatten!
      cats.map! { |g| validate_category g } # converts names to ids
      cats.sort!
      return if cats == feature_categories.sort
      update_attr :feature_categories, cats
    end

    # Add one or more groups to the list of excluded_groups.
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def add_excluded_groups(*groups)
      groups.flatten!
      groups.map! { |g| validate_excluded_group g } # converts names to ids
      new_groups = (groups + excluded_group_ids).uniq
      new_groups.sort!
      return if new_groups == excluded_group_ids.sort
      update_attr :excluded_group_ids, new_groups
    end

    # Remove one or more groups from the list of auto_groups.
    #
    # @param groups[String, Array] one or more group names, or an array of them
    #
    # @return [void]
    #
    def remove_excluded_groups(*groups)
      groups.flatten!
      current_groups = D3.computer_groups
      groups.map! { |g| current_groups[g] }
      new_groups = (excluded_group_ids - groups.compact)
      new_groups.sort!
      return if new_groups == excluded_group_ids.sort
      update_attr :excluded_group_ids, new_groups
    end


    ######  Save, Create, Update, Delete

    # create or update, as needed
    #
    def save
      @added_date ? update : create
    end

    # save a new d3 title to the d3 server
    # the d3 server will interact with the JSS
    def create
      return if @added_date
      validate_for_saving
      response = D3.cnx.post(rest_rsrc, to_json)
      @added_date = Time.parse response[:added_date]
      @last_modified = @added_date
      @changes.clear
      name
    end

    # update an existing d3 title in the d3 server
    # the d3 server will interact with the JSS
    def update
      return if @changes.empty?
      validate_for_saving
      response = D3.cnx.put rest_rsrc, to_json
      @last_modified = Time.parse response[:last_modified]
      @changes.clear
      name
    end

    def delete
      self.class.delete name
      @deleted = :deleted
    end

    def rest_rsrc
      OBJECT_RSRC + name
    end

    private

    # Parse data recieved from server into an instance.
    #
    # Note that the json here is not raw, it has already been parsed
    # by JSON.d3parse
    def init_from_json(from_json)
      super
      @changes = {}
    end

    def group_names(type)
      list =
        case type
        when :pilot then piot_group_ids
        when :auto then auto_group_ids
        when :excl then excluded_group_ids
        end
      curr_groups = D3.computer_groups.invert
      list.map! do |gid|
        curr_groups[gid] || "Missing Group: id #{gid}"
      end
      list
    end

    # Remove non-existing group ids from the
    # pilot, auto and excluded group lists
    #
    # @return [Hash{Symbol: Array}] The defunct ids, either :auto or :excluded
    #
    def clean_invalid_groups
      current_groups = D3.computer_groups

      piots_to_remove = pilot_group_ids - current_groups.values
      unless piots_to_remove.empty?
        new_group_ids = pilot_group_ids - piots_to_remove
        update_attr :pilot_group_ids, new_group_ids
      end

      autos_to_remove = auto_group_ids - current_groups.values
      unless autos_to_remove.empty?
        new_group_ids = auto_group_ids - autos_to_remove
        update_attr :auto_group_ids, new_group_ids
      end

      excls_to_remove = excluded_group_ids - current_groups.values
      unless excls_to_remove.empty?
        new_group_ids = excluded_group_ids - excls_to_remove
        update_attr :excluded_group_ids, new_group_ids
      end
    end

  end # class title

end # modle D3

require 'd3/apps/title/validation'
