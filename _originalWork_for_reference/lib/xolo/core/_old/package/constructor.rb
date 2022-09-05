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

    ############### Constructor #################

    #  Existing d3 pkgs are looked up by providing :id, :name,
    # :title, :patch, or the combination of
    # :title, :version, and :revision (which comprise the patch)
    #
    # If passed only a :title, the currently-live package for that title
    #  is used, an exception is raised if no version of the title is live.
    #
    # When creating a new d3 package use :id => :new, as for JSS::Package.
    # You must provide :name, :title, :version, and :revision.
    #
    # To add a pkg to d3 that's already in the JSS, use {Xolo::Package.import} (q.v.)
    #
    # For new (or imported) packages, you may also provide any of the other
    #   data keys mentioned in P_FIELDS.keys and they will be applied to the
    #   new Package. You may also set them after instantiation using their
    #   respective setter methods. A value for :admin must be set before
    #   calling {#create}.
    #
    def initialize (args={})

      # refresh our pkg data first
      Xolo::Package.package_data :refresh

      # if we didn't get an patch, did we get the parts?
      if args[:title] && args[:version] && args[:revision]
        args[:patch] ||= "#{args[:title]}-#{args[:version]}-#{args[:revision]}"
      end
      args[:category] ||= Xolo::CONFIG.jss_default_pkg_category

      ########## Adding a New d3/jss package
      if args[:id] == :new

        # make sure we have the needed args
        unless args[:title] and args[:version] and args[:revision]
          raise JSS::MissingDataError, "New d3 packages need :title, :version, & :revision."
        end

        # does the patch we're creating already exist?
        if Xolo::Package.all_patchs.include? args[:patch]
          raise JSS::AlreadyExistsError, "Package patch #{args[:patch]} already exists in d3"
        end

        @adding = true

      ########## Importing an existing JSS pkg?
      elsif args[:import]

        # args[:import] should only ever come from Xolo::Package.import
        # in ruby 1.8 use caller[1][/`([^']*)'/, 1] to get the label 'import'
        # doesn't matter since JSS now requires ruby 1.9.2
        raise JSS::InvalidDataError, "Use Xolo::Package.import to import existing JSS packages to d3." unless caller_locations(2,1)[0].label == "import"


        # data checking was done in the import class method
        @importing = true

      ########## Looking up an existing package by id, name, title, or patch
      else
        if args[:id]
          status =  Xolo::Package.statuses_by(:id)[args[:id]]
          if status
            @status = :missing if status == :missing
          else
            raise JSS::NoSuchItemError, "No package in d3 with id: #{args[:id]}"
          end

        elsif args[:name]
          status =  Xolo::Package.statuses_by(:name)[args[:name]]
          if status
            @status = :missing if status == :missing
            args[:id] = JSS::Package.map_all_ids_to(:name).invert[args[:name]]
          else
            raise JSS::NoSuchItemError, "No package in d3 with name: #{args[:name]}"
          end


        elsif args[:patch]
          status =  Xolo::Package.statuses_by(:patch)[args[:patch]]
          if status
            @status = :missing if status == :missing
            args[:id] = Xolo::Package.ids_to_patchs.invert[ args[:patch]]
          else
            raise JSS::NoSuchItemError, "No package in d3 with patch: #{args[:patch]}"
          end


        elsif args[:title]
          args[:id] = Xolo::Package.titles_to_live_ids[args[:title]]
          raise JSS::NoSuchItemError, "No live package for title '#{args[:title]}'" unless args[:id]
        end # if args :id

        @lookup_existing = true

      end # if args[:id] == :new

      # if the pkg is missing from the jss, there's nothing to do below here
      return if @status == :missing

      # now we have an :id (which might be :new) so let JSS::Package do its work
      # this will tie us to a new or existing jss pkg
      super args

      # does this pkg need to be added to d3?
      if @adding or @importing

        d3pkg_data = args
        @status = :unsaved
        @in_d3 = false

      else # package already exists in both JSS and d3...

        # This prevents some checks from happening, since the data came from the DB
        @initializing = true
        d3pkg_data = Xolo::Package.package_data(:refresh)[@id]
        @in_d3 = true

      end # if  @adding or @importing

      @title = d3pkg_data[:title]
      @version = d3pkg_data[:version]
      @revision = d3pkg_data[:revision]

      # process the d3 data
      if d3pkg_data

        # Loop through the field definitions for the pkg table and process each one
        # into it's ruby attribute.
        P_FIELDS.each do |fld_key, fld_def|

          # skip if we already have a value, e.g. title was set above.
          next if self.send(fld_key)

          # Note - the d3pkgdata has already been 'rubyized' via the Xolo::Database.table_records method
          # (which was used by Xolo::Package.package_data)
          fld_val = d3pkg_data[fld_key]

          # if we have a setter method for this key, call it to set the attribute.
          setter = "#{fld_key}=".to_sym
          self.send(setter, fld_val) if self.respond_to?(setter, true)  # the 'true' makes respond_to? look at private methods also

        end # PFIELDS.each
      end # if d3pkg_data

      # some nil-values shouldn't be nil
      @auto_groups ||= []
      @excluded_groups ||= []

      # expiration_bundle_ids should always be an array
      @expiration_bundle_ids ||= []

      # prohibiting_processes should always be an array
      @prohibiting_processes ||= []

      # these don't come from the table def.
      @admin = args[:admin]

      # dmg or pkg?
      @package_type = @receipt.to_s.end_with?(".dmg") ? :dmg : :pkg

      # this needs to be an array
      @apple_receipt_data ||= []

      # re-enable checks
      @initializing = false

    end # init
  end # class Package
end # module Xolo
