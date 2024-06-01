# Copyright 2024 Pixar
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

# frozen_string_literal: true

# main module
module Xolo

  module Server

    # Xolo Version/Patch as used on the Xolo Server
    #
    # NOTE be sure to only instantiate these using the
    # server's 'instantiate_version' method, or else
    # they might not have all the correct innards
    ###
    class Version < Xolo::Core::BaseClasses::Version

      # Mixins
      #############################
      #############################

      include Xolo::Server::Helpers::JamfPro
      include Xolo::Server::Helpers::TitleEditor
      include Xolo::Server::Helpers::Log

      include Xolo::Server::Mixins::VersionJamfAccess
      include Xolo::Server::Mixins::VersionTedAccess

      # Constants
      ######################
      ######################

      # On the server, xolo titles are represented by directories
      # in this directory, named with the title name.
      #
      # So a title 'foobar' would have a directory
      #    (Xolo::Server::DATA_DIR)/titles/foobar/
      #
      # In there will be a 'versions' dir containing json
      # files for each version of the title.
      #
      VERSIONS_DIRNAME = 'versions'

      # Class Methods
      ######################
      ######################

      # @pararm title [String] the title for the version
      # @return [Pathname]  The directory containing version JSON files for a title
      ######################
      def self.version_dir(title)
        Xolo::Server::Title.title_dir(title) + VERSIONS_DIRNAME
      end

      # @pararm title [String] the title for the versions
      # @return [Array<Pathname>] A list of all known versions for a title
      ######################
      def self.version_files(title)
        version_dir(title).mkpath
        version_dir(title).children
      end

      # @pararm title [String] the title for the version
      # @return [Array<String>] A list of all known versions for a title,
      #   just the basenames of all the version files with the extension removed
      ######################
      def self.all_versions(title)
        version_files(title).map { |c| c.basename.to_s.delete_suffix '.json' }
      end

      # The the local JSON file containing the current values
      # for the given version of a title
      #
      # @pararm title [String] the title for the version
      #
      # @pararm version [String] the version we care about
      #
      # @return [Pathname]
      #####################
      def self.version_data_file(title, version)
        version_dir(title) + "#{version}.json"
      end

      # Instantiate from the local JSON file containing the current values
      # for the given version of a title
      #
      # NOTE: All instantiation should happen using the #instantiate_version method
      # in the server app instance. Please don't call this method directly
      #
      # @pararm title [String] the title for the version
      #
      # @pararm version [String] the version we care about
      #
      # @return [Xolo::Server::Title] load an existing title
      #   from the on-disk JSON file
      ######################
      def self.load(title, version)
        new parse_json(version_data_file(title, version).read)
      end

      # @param patch_id [String] the id number of the patch we are looking for
      # @pararm cnx [Windoo::Connection] The Title Editor connection to use
      # @return [Boolean] Does the given patch exist in the Title Editor?
      ###############################
      def self.in_ted?(patch_id, cnx:)
        Windoo::Patch.all_ids(cnx: cnx).include? patch_id
      end

      # Attributes
      ######################
      ######################

      # The instance of Xolo::Server::App that instantiated this
      # title object. This is how we access things that are available in routes
      # and helpers, like the single Jamf and TEd
      # connections for this App instance.
      attr_accessor :server_app_instance

      # The sinatra session that instantiates this version
      # attr_writer :session

      # The Xolo::Server::Title that contains, and usually instantiated
      #   this version object
      attr_writer :title_object

      # The Windoo::Patch#patchId
      attr_accessor :ted_id_number

      # Jamf object names start with this
      attr_reader :jamf_obj_name_pfx

      # Jamf auto-install policies are named this
      attr_reader :jamf_auto_install_policy_name

      # Jamf manual install policies are named this
      attr_reader :jamf_manual_install_policy_name
      # the custom trigger is the same
      alias jamf_manual_install_trigger jamf_manual_install_policy_name

      # Jamf Patch Policy is named this
      attr_reader :jamf_patch_policy_name

      # The Jamf::Package object has this jamf id
      attr_reader :jamf_pkg_id

      # Constructor
      ######################
      ######################

      # NOTE: be sure to only instantiate these using the
      # servers 'instantiate_version' method, or else
      # they might not have all the correct innards
      def initialize(data_hash)
        super

        # These attrs aren't defined in the ATTRIBUTES
        # and/or are not stored in the on-disk json file

        @ted_id_number ||= data_hash[:ted_id_number]
        @jamf_pkg_id ||= data_hash[:jamf_pkg_id]

        # and these can be generated now
        @jamf_obj_name_pfx = "#{JAMF_OBJECT_NAME_PFX}#{title}-#{version}"

        @jamf_pkg_name ||= @jamf_obj_name_pfx

        @jamf_auto_install_policy_name = "#{jamf_obj_name_pfx}#{JAMF_POLICY_NAME_AUTO_INSTALL_SFX}"
        @jamf_manual_install_policy_name = "#{jamf_obj_name_pfx}#{JAMF_POLICY_NAME_MANUAL_INSTALL_SFX}"

        @jamf_patch_policy_name = @jamf_obj_name_pfx

        # we set @jamf_pkg_file when a pkg is uploaded
        # since we don't know until then if its a .pkg or .zip
        # It will be stored in the local data and reloaded as needed
      end

      # Instance Methods
      ######################
      ######################

      # @see #groups_to_use
      #
      # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
      #   if nil, we'll instantiate it now
      #
      # @return [Array<String>] the pilot groups to use in policies and patch policies
      ######################
      def pilot_groups_to_use(ttl_obj: nil)
        return @pilot_groups_to_use if @pilot_groups_to_use

        ttl_obj ||= title_object
        @pilot_groups_to_use = groups_to_use ttl_obj.pilot_groups, pilot_groups
      end

      # @see #groups_to_use
      #
      # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
      #   if nil, we'll instantiate it now
      #
      # @return [Array<String>] the excluded groups to use in policies and patch policies for this version
      ######################
      def excluded_groups_to_use(ttl_obj: nil)
        return @excluded_groups_to_use if @excluded_groups_to_use

        ttl_obj ||= title_object
        # log_debug "sending excluded_groups to 'groups_to_use' method: #{excluded_groups} #{excluded_groups.class}"
        @excluded_groups_to_use = groups_to_use ttl_obj.excluded_groups, excluded_groups

        # always exclude Xolo::Server.config.forced_exclusion if defined
        if Xolo::Server.config.forced_exclusion
          @excluded_groups_to_use << Xolo::Server.config.forced_exclusion
          log_debug "Appended Xolo::Server.config.forced_exclusion '#{Xolo::Server.config.forced_exclusion}' to excluded groups"
        end
        @excluded_groups_to_use
      end

      # @see #groups_to_use
      #
      # @param ttl_obj [Xolo::Server::Title] The pre-instantiated title for ths version.
      #   if nil, we'll instantiate it now
      #
      # @return [Array<String>] the excluded groups to use in policies and patch policies
      ######################
      def release_groups_to_use(ttl_obj: nil)
        return @release_groups_to_use if @release_groups_to_use

        ttl_obj ||= title_object
        @release_groups_to_use = groups_to_use ttl_obj.release_groups, release_groups
        @release_groups_to_use = [Xolo::TARGET_ALL] if @release_groups_to_use.include? Xolo::TARGET_ALL
        @release_groups_to_use
      end

      # Given some scope-groups defined in the title and the version, which should we use?
      #
      # Version-specific will always override title-defaults, like so
      #
      # If the verison_groups is a non-empty array, use those groups.
      # If the version_groups is nil or an empty array, use the ones from the title, if any.
      # if the version_groups contains Xolo::NO_SCOPED_GROUPS ('no-scoped-groups') then dont
      #   use any groups even if the title has some defined
      #
      # IMPORTANT: never return the actual groups we are given, otherwise the ones
      # inside the title or version objects will be mucked with by subsequent operations.
      #
      # @param title_groups [Array<String>] the groups defined in the title object
      #
      # @param title_groups [Array<String>] the groups defined in the version object
      #
      # @return [Array<String>] the groups to use in policies and patch policies for this version
      ######################
      def groups_to_use(title_groups, version_groups)
        grps = []

        # log_debug "Method groups_to_use: comparing title groups #{title_groups} (#{title_groups.class}) to version groups #{version_groups} (#{version_groups.class})"

        if version_groups.include? Xolo::NO_SCOPED_GROUPS
          grps

        elsif version_groups.pix_empty?
          grps += title_groups

        elsif version_groups.is_a? Array
          grps += version_groups

        else
          grps
        end
      end

      # @return [Hash]
      ###################
      def session
        server_app_instance&.session || {}
        # @session ||= {}
      end

      # @return [String]
      ###################
      def admin
        session[:admin]
      end

      # Append a message to the progress stream file,
      # optionally sending it also to the log
      #
      # @param message [String] the message to append
      # @param log [Symbol] the level at which to log the message
      #   one of :debug, :info, :warn, :error, :fatal, or :unknown.
      #   Default is nil, which doesn't log the message at all.
      #
      # @return [void]
      ###################
      def progress(msg, log: :debug)
        server_app_instance.progress msg, log: log
      end

      # This might have been set already if we were instantiated via our title
      # @return [Xolo::Server::Title] the title for this version
      ################
      def title_object(refresh: false)
        @title_object = nil if refresh
        @title_object ||= server_app_instance.instantiate_title title
      end

      # @return [Windoo::Connection] a single Title Editor connection to use for
      #   the life of this instance
      #############################
      def ted_cnx
        # @ted_cnx ||= super
        server_app_instance.ted_cnx
      end

      # @return [Jamf::Connection] a single Jamf Pro API connection to use for
      #   the life of this instance
      #############################
      def jamf_cnx
        # @jamf_cnx ||= super
        server_app_instance.jamf_cnx
      end

      # The data file for this version
      # @return [Pathname]
      #########################
      def version_data_file
        self.class.version_data_file title, version
      end

      # TODO: maybe pass in an appropriate Windoo::SoftwareTitle, so
      # we don't have to use refresh all the time to re-fetch, if we just
      # re-fetched from elsewhere?
      #
      # @return [Windoo::Patch] The Windoo::Patch object that represents
      #   this version in the title editor
      #############################
      def ted_patch(refresh: false)
        @ted_patch = nil if refresh
        @ted_patch ||= ted_title(refresh: refresh).patches.patch(version)
      end

      # @return [Windoo::SoftwareTitle] The Windoo::SoftwareTitle object that represents
      #   this version's title in the title editor
      #############################
      def ted_title(refresh: false)
        @ted_title = nil if refresh
        @ted_title ||= Windoo::SoftwareTitle.fetch id: title, cnx: ted_cnx
      end

      # override the autogenerated getter, and
      # get this value every time we look at it
      # TODO: Maintain this value locally
      def deployable
        # ted_patch&.enabled?
      end

      # Save a new version, adding to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      # This should be running in the context of #with_streaming
      #
      # @return [void]
      #########################
      def create
        self.creation_date = Time.now
        self.created_by = admin
        self.status = STATUS_PENDING
        # log_debug "creation_date: #{creation_date}, created_by: #{created_by}"

        self.modification_date = Time.now
        self.modified_by = admin
        # log_debug "modification_date: #{modification_date}, modified_by: #{modified_by}"

        # save to file here so that we have something to delete if
        # the next couple steps fail
        progress 'Saving version data to Xolo server'
        save_local_data

        # progress_stream << 'Saved version data to Xolo server'
        create_patch_in_ted
        enable_ted_patch

        create_in_jamf

        self.status = STATUS_PILOT

        # save to file again now, because saving to TitleEd and Jamf will
        # add some data
        save_local_data

        # TODO: allow specification of version_order, probably by accepting a value
        # for the 'previous_version'?
        # prepend our version to the version_order array of the title
        progress "Updating title version_order, prepending '#{version}'", log: :debug

        title_object.version_order.unshift version
        title_object.save_local_data

        progress "Version '#{version}' of Title '#{title}' has been created in Xolo.", log: :info
      end

      # Update a this version, updating to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      #
      #
      # TODO: allow specification of version_order, probably by accepting a value
      # for the 'previous_version'?
      #
      # @param new_data [Hash] The new data sent from xadm
      # @return [void]
      #########################
      def update(new_data)
        @new_data_for_update = new_data
        log_info "Updating version '#{version}' of title '#{title}' for admin '#{admin}'"

        self.modification_date = Time.now
        self.modified_by = admin

        update_patch_in_ted
        enable_ted_patch

        # TODO:  update in Jamf if needed = e.g. scoping

        # update local data before saving back to file
        ATTRIBUTES.each do |attr, deets|
          next if deets[:read_only]

          new_val = @new_data_for_update[attr]
          old_val = send(attr)
          next if new_val == old_val

          log_debug "Updating Xolo attribute '#{attr}': #{old_val} -> #{new_val}"
          send "#{attr}=", new_val
        end

        # save to file last, because saving to TitleEd and Jamf will
        # add some data
        save_local_data

        # TODO: upload any new pkg
      end

      # Save our current data out to our JSON data file
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_local_data
        self.class.version_dir(title).mkpath

        file = version_data_file
        log_debug "Saving local version data to: #{file}"
        file.pix_atomic_write to_json
      end

      # Delete the version
      #
      # @param update_title [Boolean] Update the title for this version to
      #   know the version is gone. Set this to false when the title itself
      #   is being deleted and calling this method.
      #
      # @return [void]
      ##########################
      def delete(update_title: true)
        delete_patch_from_ted
        delete_version_from_jamf

        # remove from the title's list of versions
        if update_title
          title_object.version_order.delete version
          progress 'Removing version from title data on the Xolo server', log: :debug
          title_object.save_local_data
        end

        # delete the local data
        progress 'Deleting version data from the Xolo server', log: :info
        version_data_file.delete
        progress "Version '#{version}' of Title '#{title}' has been deleted from Xolo.", log: :info
      end

      # Add more data to our hash
      ###########################
      def to_h
        hash = super

        # These attrs aren't defined in the ATTRIBUTES
        hash[:jamf_pkg_id] = jamf_pkg_id
        hash[:ted_id_number] = ted_id_number

        hash
      end

    end # class Version

  end # module Server

end # module Xolo
