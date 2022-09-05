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

module Xolo

  # A version available in a title in d3.
  #
  # This file defines values and methods used on the D3 client tools
  # d3 and d3admin
  #
  class Version < AbstractVersion

    # Constants
    ##############################

    LIST_RSRC = 'versions'.freeze

    # Class Methods
    ##############################

    def self.all(*attribs)
      attribs.empty? ? Xolo.cnx.get(LIST_RSRC) : Xolo.cnx.get("#{LIST_RSRC}/?fields=#{attribs.join ','}")
    end

    def self.all_for_title(title)
      all.select { |v| v[:title] == title }
    end

    def self.all_released
      all.select { |v| v[:status] == STATUS_RELEASED }
    end

    def self.all_pilot
      all.select { |v| v[:status] == STATUS_PILOT }
    end

    def self.all_skipped
      all.select { |v| v[:status] == STATUS_SKIPPED }
    end

    def self.all_deprecated
      all.select { |v| v[:status] == STATUS_DEPRECATED }
    end

    # Fetch an existing version
    def self.fetch(title, version)
      validate_version_exists(title, version)

      rsrc = "#{Xolo::Title::OBJECT_RSRC}#{title}/version/#{CGI.escape version}"

      new from_json: Xolo.cnx.get(rsrc)
    end

    # delete a version
    def self.delete(title, version)
      validate_version_exists(title, version)
      rsrc = "#{Xolo::Title::OBJECT_RSRC}#{title}/version/#{CGI.escape version}"
      Xolo.cnx.delete rsrc
    end

    # Public Instance Methods
    ##############################

    ##### Setters

    # All setters do their work here,
    # which not only updates the attr value
    # but records the change to be logged on the
    # server in the titles changelog
    def update_attr(attr, newval)
      @changes[attr] ||= {}
      @changes[attr][:orig] = send(attr) unless @changes[attr].key? :orig
      @changes[attr][:new] = newval
      instance_variable_set "@#{attr}", newval
    end

    # TODO: prevent MinOS > MaxOS
    def minimum_os=(os_version)
      os_version = validate_os_version os_version
      return if os_version == @minimum_os
      update_attr :minimum_os, os_version
    end

    # TODO: prevent MinOS > MaxOS
    def maximum_os=(os_version)
      os_version = validate_os_version os_version
      return if os_version == @minimum_os
      update_attr :maximum_os, os_version
    end

    # TODO: use the min and max OS version to set the package
    # OS requirements

    def remove_first=(bool)
      bool = JSS::Validate.boolean bool, 'remove_first must be boolean true or false'
      return if bool == @remove_first
      update_attr :remove_first, bool
    end

    # @param script[String] the name of the script
    #
    def pre_install_script=(script)
      id = validate_script script
      return if @pre_install_script_id == id
      update_attr :pre_install_script_id, id
    end

    # @param script[String] the name of the script
    #
    def post_install_script=(script)
      id = validate_script script
      return if @post_install_script_id == id
      update_attr :post_install_script_id, id
    end

    # @param script[String] the name of the script
    #
    def pre_remove_script=(script)
      id = validate_script script
      return if @pre_remove_script_id == id
      update_attr :pre_remove_script_id, id
    end

    # @param script[String] the name of the script
    #
    def post_remove_script=(script)
      id = validate_script script
      return if @post_remove_script_id == id
      update_attr :post_remove_script_id, id
    end


    # @param pkg[String] the name of the pkg
    #
    def package=(pkg)
      id = validate_package pkg
      return if @package_id == id
      update_attr :package_id, id
    end

    def removable=(_new_val)
      bool = JSS::Validate.boolean bool, 'removable: must be boolean true or false'
      return if bool == @removable
      update_attr :removable, bool
    end

    def reboot_required=(_new_val)
      bool = JSS::Validate.boolean bool, 'reboot_required: must be boolean true or false'
      return if bool == @reboot_required
      pdate_attr :reboot_required, bool
    end

    #### PatchSource setters

    def killapps=(*newapps)
      newapps.flatten!
      newapps.each { |ka| validate_killapp ka }
      return if newapps.sort == killapps.sort
      update_attr :killapps, newapps
    end

    def add_killapp(killapp)
      valdate_killapp(killapp)
      return if @killapps.key?(killapp.id)
      @killapps[ka.id] = kill_app
      @need_to_update = true
    end

    def remove_killapp(ka)
      return unless @killapps.key?(ka.id)
      @killapps.delete ka_id
      @need_to_update = true
    end

    # def standalone=(bool)
    #   bool = JSS::Validate.boolean bool, 'standalone must be boolean true or false'
    #   return if bool == @standalone
    #   @standalone = bool
    #   @need_to_update = true
    # end
    #
    # def add_client_components(component)
    #   return if component == @client_components.first
    #   valdate_client_component(component) # nil is ok???
    #   @client_components = [component]
    #   @need_to_update = true
    # end
    #
    # def remove_client_components
    #   return if @client_components.empty?
    #   @client_components = []
    #   @need_to_update = true
    # end
    #
    # def client_capabilities=(capabilities)
    #   return if capabilities == @client_capabilities
    #   valdate_client_capabilities(capabilities) # nil is ok???
    #   @client_capabilities = capabilities
    #   @need_to_update = true
    # end

    # make_live:  see Title.released_version=

    # Getters

    def pre_install_script
      script_name pre_install_script_id
    end

    def post_install_script
      script_name post_install_script_id
    end

    def pre_remove_script
      script_name pre_remove_script_id
    end

    def post_remove_script
      script_name post_remove_script_id
    end

    # create or update, as needed
    #
    def save
      @added_date ? update : create
    end

    # save a new d3 version to the d3 server
    # the d3 server will interact with the JSS
    def create
      return if @added_date
      response = Xolo.cnx.post rest_rsrc, to_json
      @id = response[:id]
      @added_date = Time.parse response[:added_date]
      @changes.clear
      :created
    end

    # update an existing d3 version in the d3 server
    # the d3 server will interact with the JSS
    def update(admin)
      return if @changes.empty?
      JSS::Validate.non_empty_string admin, 'admin name must be provided for updating'
      Xolo.cnx.put rest_rsrc, to_json
      @changes.clear
    end

    def delete
      self.class.delete id
    end

    def rest_rsrc
      "#{Xolo::Title::OBJECT_RSRC}#{title}/version/#{CGI.escape version}"
    end

    private

    def script_name(id)
      return nil if id.nil?
      Xolo.scripts.invert[id]
    end

  end # class version

end # module Xolo

require 'xolo/apps/version/validation'
