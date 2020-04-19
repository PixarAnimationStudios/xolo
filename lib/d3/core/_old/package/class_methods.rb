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

    ############### Class Methods #################

    #### These methods return Hashes or Arrays of
    # data about d3 packages without instantiating
    # the objects themselves

    # Raw(ish) SQL data for all d3 packages as a Hash of Hashes.
    #
    # The keys are the JSS ids of the packages
    #
    # The values are records from the d3_packages table, as Hashes
    # with keys matching the keys of {D3::Database::PACKAGE_TABLE}[:field_definitions]
    # plus these fields from the JSS's packages table:
    #    :name, :require_reboot, :oses, :required_processor
    #
    # This raw data, queried directly via SQL, lets
    # us process lists of packages without instantiating
    # each one as a D3::Package object, which is slow
    # due to API calls for each package.
    # We can use this data to instantiate
    # those package objects when they are actually needed.
    #
    # @param refresh[Boolean] should the data be re-read from the database?
    #
    # @param status[Symbol] return only data for packages with this status. See {D3::title::STATUSES}, defaults to :all
    #
    # @return [Hash<Hash>] database data about all packages known to d3
    #
    def self.package_data(refresh = false, status = :all)
      @@package_data = nil if refresh

      if @@package_data.nil?

        # get a few fields from the JSS package data
        # store them in a hash keyed by id
        #jss_q = "SELECT package_id, package_name, os_requirements, require_reboot, required_processor  FROM #{JSS::Package::DB_TABLE} WHERE package_id IN (SELECT package_id from #{P_TABLE[:table_name]})"
        jss_q = "SELECT package_id, package_name, os_requirements, require_reboot, required_processor, allow_uninstall FROM #{JSS::Package::DB_TABLE}"

        r = JSS::DB_CNX.db.query jss_q
        jss_data = {}
        r.each_hash{|jpkg| jss_data[jpkg["package_id"].to_i] = jpkg }

        r.free

        # get the table records and add in the appropriate names
        @@package_data = {}

        D3::Database.table_records(D3::Package::P_TABLE).each do |p|
          d3_id = p[:id]

          @@package_data[d3_id] = p

          @@package_data[d3_id][:patch] = "#{p[:title]}-#{p[:version]}-#{p[:revision]}"

          # D3::Database.table_records returns NULL as nil even if converting with STRING_TO_INT
          # which in general is a good thing, but expiration should always be an integer and NULL should be 0
          @@package_data[d3_id][:expiration] = p[:expiration].to_i

          jinfo = jss_data[d3_id]

          # is this pkg still in the JSS?
          if jinfo
            @@package_data[d3_id][:name] = jinfo["package_name"]
            @@package_data[d3_id][:oses] = jinfo["os_requirements"]
            @@package_data[d3_id][:reboot] = (jinfo["require_reboot"] == "1") # boolean
            @@package_data[d3_id][:required_processor] = jinfo["required_processor"]
            @@package_data[d3_id][:removable] = (jinfo["allow_uninstall"] == "1")
          # or is it missing?
          else
            @@package_data[d3_id][:status] = :missing
            @@package_data[d3_id][:name] = "** missing from jss **"
            @@package_data[d3_id][:oses] = ""
            @@package_data[d3_id][:reboot] = false
            @@package_data[d3_id][:required_processor] = "None"
            @@package_data[d3_id][:removable] = false
          end #  if jinfo
        end #  D3::Database.table_records(D3::Package::P_TABLE).each do |p|
      end # if @@package_data.nil?

      if status == :all
        return @@package_data
      else
        raise JSS::InvalidDataError, "status must be one of :#{STATUSES.join(', :')}" unless STATUSES.include? status
        # reject because Hash#select returns an array of arrays
        return @@package_data.reject{|id,p|  p[:status] != status }
      end #if status == :all
    end #  self.package_data(refresh = false, status = :all)

    # A Hash of package identifiers (id's, names, patchs)
    # as keys, to the status of the package (symbols)
    #
    # @param identifier[Symbol] one of :id, :name, or :patch
    #
    # @return [Hash{String,Integer => Symbol] the statuses of the packages
    #
    def self.statuses_by (identifier, refresh = false)
      raise JSS::InvalidDataError, "identifier must be one of :id, :patch, or :name" unless [:id, :name, :patch].include? identifier
      stati = {}
      self.package_data(refresh).values.each{|pkg| stati[pkg[identifier]] = pkg[:status] }
      stati
    end # statuses by

    # A Hash mapping package ids to patchs in d3
    #
    # A package's 'patch' is the combination of its title, version, and revision,
    # joined with hyphens into a String, which must be unique in d3.
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Hash{Integer => String}] the current patchs in d3
    #
    def self.ids_to_patchs(refresh = false )
      pd = self.package_data(refresh)
      pd.merge(pd){|id,p| p[:patch]}
    end

    # An Array of ids for all pkgs with a given title
    #
    # @param title[String] the title to look for
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array] The package ids with the desired title
    #
    def self.ids_for_title(title, refresh = false)
      self.package_data(refresh).values.select{|p| p[:title] == title}.map{|p| p[:id]}
    end

    # An Array of all packages ids known to d3
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array<Integer>] the pkg ids known to d3
    #
    def self.all_ids(refresh = false)
      self.package_data(refresh).keys
    end

    # An Array of all packages names known to d3
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array<String>] the pkg names known to d3
    #
    def self.all_names(refresh = false)
      self.package_data(refresh).values.map{|p| p[:name]}
    end

    # An Array of titles known to d3
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array<String>] the titles known to d3
    #
    def self.all_titles(refresh = false)
      self.package_data(refresh).values.map{|p| p[:title] }.uniq
    end

    # An Array of patchs known to d3
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array<String>] the titles known to d3
    #
    def self.all_patchs(refresh = false)
      self.package_data(refresh).values.map{|p| p[:patch] }
    end

    # A Hash of all packages filenames keyed by pkg id
    # These are looked up via a DB query because otherwise
    # we'd have to instantiate a Package object for every package
    # which is way too slow.
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Hash{Integer: String}] the pkg filenames
    #
    def self.all_filenames(refresh = false)
      @@filenames = nil if refresh
      return @@filenames if @@filenames
      @@filenames = {}
      qr = JSS::DB_CNX.db.query "SELECT package_id, file_name FROM packages WHERE package_id IN (SELECT package_id FROM #{D3::Package::P_TABLE[:table_name]})"
      qr.each_hash{|p| @@filenames[p["package_id"].to_i] =  p["file_name"]}
      qr.free
      @@filenames
    end

    # A Hash of Package Data for all live packages
    #
    # This is the {D3::Package.package_data} Hash, limited to
    # those packages whose status is :live, i.e. the package
    # that gets installed for its title.
    #
    # @return [Hash{Integer=>Hash}] The live pacakge data
    #
    def self.live_data(refresh = false)
      self.package_data(refresh, :live)
    end

    # A Hash mapping all titles to their currently live jss id
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Hash{String => Integer}] The titles and id's of all live packages
    #
    def self.titles_to_live_ids(refresh = false)
      # Hashes don't have #map, so #merge back onto ourselves to have the
      # same effect.
      lp = self.live_data(refresh)
      lp.merge(lp){|id,p| p[:title] }.invert
    end

    # An Array of all packages ids that are live
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array<String>] the live pkg ids
    #
    def self.live_ids(refresh = false)
      self.live_data(refresh).keys
    end

    # An Array of all packages names that are live
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array<String>] the pkg names known to d3
    #
    def self.live_names(refresh = false)
      self.live_data(refresh).values.map{|p| p[:name]}
    end

    # An Array of titles that have live packages.
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array] the live titles
    #
    def self.live_titles(refresh = false)
      self.titles_to_live_ids(refresh).keys
    end

    # A Hash of Package Data for all "pilot" packages
    #
    # This is the {D3::Package.package_data} Hash, limited to
    # those packages whose status is :pilot, i.e. they are not live
    # and are newer than the live pkg for their title.
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Hash<Hash>] the pilotable packages known to d3
    #
    def self.pilot_data(refresh = false)
      self.package_data(refresh, :pilot)
    end

    # A Hash of Package Data for all "deprecated" packages
    #
    # This is the {D3::Package.package_data} Hash, limited to
    # those packages whose status is :depreicated. These packages
    # were once live, and still exist in the JSS and can
    # be made live again, though that isn't recommended.
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array<Hash>] the deprecated packages known to d3
    #
    def self.deprecated_data(refresh = false)
      self.package_data(refresh, :deprecated)
    end

    # A Hash of Package Data for all "skipped" packages
    #
    # This is the {D3::Package.package_data} Hash, limited to
    # those packages whose status us :skipped - i.e. the were never
    # made live before a newer pkg of the same title was made live.
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array<Hash>] the deprecated packages known to d3
    #
    def self.skipped_data(refresh = false)
      self.package_data(refresh, :skipped)
    end

    # A Hash of Package Data for all "missing" packages
    #
    # This is the {D3::Package.package_data} Hash, limited to
    # those packages whose status us :missing - i.e. the package
    # id no longer exists in the JSS.
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Array<Hash>] the missing packages known to d3
    #
    def self.missing_data(refresh = false)
      self.package_data(refresh, :missing)
    end



    # Get a single D3::Package by using a search term.
    #
    # The term is searched in this order:
    # patch, title, id, display name, filename.
    #
    # If title, returns the currently live pkg
    #
    # The first match is returned, nil if no match
    #
    # @param search_term[String] the thing to look for
    #
    # @param type[Symbol] either :pkg to return a D3::Package or
    #   :hash to return the raw D3::Package.package_data hash
    #   for the matching package. This is quicker and doesn't
    #   instantiate a Package Object from the API.
    #
    # @return [D3::Package, nil] the package that was found.
    #
    def self.find_package(search_term, type = :pkg )
      return nil if search_term.nil?

      if self.all_patchs.include? search_term
        id = D3::Package.ids_to_patchs.invert[search_term]

      elsif self.all_titles.include? search_term
        id = self.titles_to_live_ids[search_term]

      elsif self.all_ids.include? search_term.to_i
        id = search_term.to_i

      elsif self.all_names.include? search_term
        id = D3::Package.map_all_ids_to(:name).invert[search_term]

      elsif self.all_filenames.values.include? search_term
        id = self.all_filenames.invert[search_term]

      else
        return nil
      end # if elsif.....

      return nil unless id and id.is_a? Fixnum

      return type == :pkg ? D3::Package.new(:id => id) : self.package_data[id]
    end

    # Get the most recent package on the server
    # for a given title
    #
    # @param title[String] the title to look for
    #
    # @return [D3::Package, nil] the most recent package, or nil if none
    #
    def self.most_recent_package_for(title)
      return nil unless D3::Package.all_titles.include? title
      # deal with potentially missing pkgs:
      # start with the highest id until we find an existing one
      self.ids_for_title(title).sort.reverse.each do |id|
        begin
          pkg = D3::Package.new :id => id
          return pkg
        rescue JSS::NoSuchItemError
          next
        end
      end
      return nil
    end

    # A Hash of Hashes of all scripts used by d3 packages.
    # Each key is a script ID,
    # Each value is a sub-Hash with one entry per d3 pkg that uses the script.
    #
    # The sub-Hashes have pkg id's as keys, and an Array of
    # script usages as values. (since a pkg can use the same
    # script for any or all of the 4 script types)
    #
    # Example:
    # {
    #   123 => { 234 => [:pre_install] },
    #
    #   456 => { 234 => [:post_install],
    #            345 => [:post_install, :pre_remove] }
    # }
    #
    # In the example above,
    #   - script id 123 is used by pkg id 234 as a pre-install script
    #   - script id 456 is used by pkg id 234 as a post-install script
    #     and used by pkg id 345 as both a post-install and pre-remove script.
    #
    # @param refresh [Boolean] should the data be re-read from the database?
    #
    # @return [Hash{Integer => Hash{Integer => Array<Symbol>}}] the scripts used by packages in d3
    #
    def self.scripts(refresh = false)
      scripts = {}
      self.package_data(refresh, :all).each do |pkg_id, pkg_data|
        SCRIPT_TYPES.each do |script_type|
          script_id_key = "#{script_type}_script_id".to_sym
          if pkg_data[script_id_key]
            scr_id = pkg_data[script_id_key]
            scripts[scr_id] ||= {}
            scripts[scr_id][pkg_id] ||= []
            scripts[scr_id][pkg_id] << script_type
          end
        end # each script type
      end # do each pkg_id, pkg_data
      scripts
    end

    # An Array of pkg ids for all pkgs that use a given script,
    # optionally limiting to those pkgs that use the script
    # for a given purpose.
    #
    # @param script[Integer,String] The name or ID number of the script
    #
    # @param script_type[Symbol,nil] The script-type by which to limit the results.
    #   One of SCRIPT_TYPES, or nil for all types
    #
    # @param refresh[Boolean] Should the data be re-read from the server?
    #
    # @return [Array<Integer>] the ids for each package that uses the script
    #
    def self.packages_for_script (script, script_type = nil, refresh = false)

      if script_type
        raise JSS::InvalidDataError, "Script type must be one of :#{SCRIPT_TYPES.join(' :')}" unless SCRIPT_TYPES.include? script_type
      end # if screipt type

      pkgs = []

      # confirm the ID of the script..
      sid = JSS::Script.all_ids(refresh).include?(script) ? script : nil
      sid ||= JSS::Script.map_all_ids_to(:name).invert[script]

      # script id has to exist in JSS and some d3 pkg
      return pkgs unless sid and self.scripts(refresh)[sid]

      self.scripts(refresh)[sid].each do |pkg_id, uses|
        if script_type
          pkgs << pkg_id if uses.include? script_type
        else
          pkgs << pkg_id
        end
      end # each script id, pkgs

      pkgs
    end

    # An array of ids for all pkgs that are auto-installed for
    # a given computer group. Returns an empty array if no such group.
    #
    # @param group[String] the name of the JSS group for which to find
    #   ids
    #
    # @param refresh[Boolean] should the data be re-read from the db?
    #
    # @return [Array<Integer>] the ids auto-installed for that group
    #
    def self.auto_install_ids_for_group (group, refresh = false)
      pkgs = D3::Package.package_data(refresh).values
      pkgs.select{|p| p[:auto_groups].include? group}.map{|p| p[:id]}
    end

    # An array of ids for all pkgs that are exclude for a given
    # computer group. Returns an empty array if no such group.
    #
    # @param group[String] the name of the JSS group for which to find
    #   ids
    #
    # @param refresh[Boolean] should the data be re-read from the db?
    #
    # @return [Array<Integer>] the ids excluded for that group
    #
    def self.exclude_ids_for_group (group, refresh = false)
      pkgs = D3::Package.package_data(refresh).values
      pkgs.select{|p| p[:excluded_groups].include? group}.map{|p| p[:id]}
    end




    # Import an existing JSS::Package into d3.
    #
    # A d3 title and version must be provided.
    #
    # If no revision is provided, it is set to 1.
    #
    # If the JSS package is an Apple installer pkg, the read-only password for the
    # current distribution point must be provided so that the Apple package
    # identifier(s) can be queried from the pkg on the server.
    #
    # After the D3::Package is instantiated, these and other d3-specific values
    # can be changed before creating it on the server.
    #
    # IMPORTANT: Even though the JSS package already exists, you must call
    # {#create} after instantiating this new D3::Package in order to save it
    # into d3.
    #
    # @param ident[String,Integer] the name or id of the JSS::Package to import.
    #
    # @param args[Hash] The d3-specific values for this package. Here are some
    #   of the important ones for importing.
    #   See {#initialize} for more details.
    #
    # @option args :title[String] The d3 title to which this package will belong
    #
    # @option args :version[String] The version of the thing installed.
    #
    # @option args :revision[Integer] The revision of this pkg version in d3. Defaults to 1.
    #
    # @option args :dist_pw[String] The read-only or read-write password for the distribution point for this machine.
    #
    # @option args :unmount[Boolean] Should the dist.point be unmounted after this? Defaults to true
    #
    # @return [D3::Package] The newly imported d3 package object,
    #   not yet saved as a d3 pkg on the server
    #
    def self.import (ident, args)
      id = if JSS::Package.all_ids.include? ident
        ident
      else
        JSS::Package.map_all_ids_to(:name).invert[ident]
      end
      raise JSS::NoSuchItemError, "No JSS Package with name or id matching '#{ident}'" unless id
      raise JSS::AlreadyExistsError, "That JSS package already exists in d3" if self.all_ids.include? id

      raise JSS::MissingDataError, "Importing packages requires :title" unless args[:title]
      raise JSS::MissingDataError, "Importing packages requires :version" if args[:version].to_s.strip.empty?

      args[:revision] ||= 1

      jss_pkg = JSS::Package.new :id => id

      tmp_patch = "#{args[:title]}-#{args[:version]}-#{args[:revision]}"
      if self.all_patchs.include? tmp_patch
        raise JSS::InvalidDataError, "A d3 pkg for patch #{tmp_patch} already exists."
      end # unless

      args[:id] = id
      args[:import] = true
      args[:unmount] = true if args[:unmount].nil?

      imported_pkg = self.new(args)
      imported_pkg.update_apple_receipt_data args[:dist_pw],  args[:unmount]
      imported_pkg
    end

    # Check for existence of one or more computer groups in the JSS,
    # raise an exception if any group doesn't exist.
    #
    # @param groups[String,Array<String>] the group name(s) to check, if string, comma-separated.
    #
    # @return [Array<String>] valid, existing group names.
    #
    def self.check_computer_groups(groups)
      parsed_groups = JSS.to_s_and_a(groups)
      parsed_groups[:arrayform].each do |g|
        raise JSS::NoSuchItemError, "No ComputerGroup named '#{g}' in the JSS" unless JSS::ComputerGroup.all_names.include? g
      end
      return parsed_groups[:arrayform]
    end

    # Givin a Pathname to a package, return an array of
    # hashes with data for all the pkg rcpts that will be installed
    # each hash includes at least :apple_pkg_id, :version, and :installed_kb
    #
    # Thanks to Greg Neagle for inspiration on this method from munkicommon.py
    #
    # @param pkg_path[String,Pathname] the path to a .pkg to scan
    #
    # @return [Array<Hash>] the Apple receipt data for the pkg
    #
    def self.receipt_data_from_pkg (pkg_path)
      pkg_path = Pathname.new(pkg_path) unless pkg_path.is_a? Pathname
      raise "The path given must end with .pkg or .mpkg" unless pkg_path.to_s =~ PKG_RE
      raise "Package '#{pkg_path}' doesn't exist" unless pkg_path.exist?

      if pkg_path.directory?
        self.receipt_data_from_bundle_pkg(pkg_path).uniq
      else
        self.receipt_data_from_flat_pkg(pkg_path).uniq
      end
    end # def receipt_data_from_pkg (pkg_path)

    # Givinn a Pathname to a flat package, return an array of
    # hashes with data for all the pkg rcpts hat will be installed
    # each has includes at least :apple_pkg_id, :version, and :installed_kb
    #
    # Thanks to Greg Neagle for inspiration on this method from munkicommon.py
    #
    def self.receipt_data_from_flat_pkg (pkg_path)

      pkg_path = Pathname.new(pkg_path)
      rcpts = []

      pkg_contents = `/usr/bin/xar -tf #{Shellwords.escape pkg_path.to_s}`
      raise "Could not look at contents of flat package #{pkg_path.title}" unless $CHILD_STATUS.exitstatus == 0

      start_dir = Pathname.pwd
      work_dir = Pathname.new Dir.mktmpdir
      Dir.chdir work_dir

      begin
        # loop thru the items in the flat pkg
        # extracting any PackageInfo and Distribution files
        xml_files = []

        pkg_contents.each_line do |line|
          line.chomp!

          # if there's a top level Dist or PackageInfo, use it exclusively
          if line. == "PackageInfo" or line == "Distribution"
            xml_files = [line]
            break

          # otherwise find all sub PackageInfos
          elsif line.end_with? ".pkg/PackageInfo"
            xml_files << line
          end

        end # pkg_contents.each_line do line

        # Extract whatever files we found interesting
        xml_files.each do |xml_file|
          system "/usr/bin/xar", "-xf", pkg_path.to_s, xml_file
          raise raise "Error reading #{xml_file} from flat package #{pkg_path.title}" unless $CHILD_STATUS.exitstatus == 0
          extracted_file = work_dir + xml_file
          rcpts += self.receipt_data_from_xml(extracted_file, pkg_path)
        end # xml files.each

      ensure
        Dir.chdir start_dir
        work_dir.rmtree
      end # begin

      rcpts

    end # def receipt_data_from_flat_pkg (pkg_path)

    # givin a Pathname to a bundle pkg,  return an array of
    # hashes with data for all the pkg rcpts hat will be installed
    # each has includes at least :apple_pkg_id, :version, and :installed_kb
    #
    # Thanks to Greg Neagle for inspiration on this method from munkicommon.py
    #
    def self.receipt_data_from_bundle_pkg (pkg_path)
      pkg_path = Pathname.new(pkg_path) unless pkg_path.is_a? Pathname
      rcpts = []

      # if this is a single pkg, not a metapkg, data comes from Info.plist
      if pkg_path.to_s.end_with? ".pkg"
        rcpt_data = {}
        info_plist = pkg_path + "Contents/Info.plist"
        if info_plist.exist?
          plist = D3.parse_plist info_plist
          rcpt_data[:apple_pkg_id] = plist["CFBundleIdentifier"]
          rcpt_data[:apple_pkg_id] ||= plist["Bundle Identifier"]
          rcpt_data[:apple_pkg_id] ||= pkg_path.title.to_s

          rcpt_data[:installed_kb] = plist["IFPkgFlagInstalledSize"]

          rcpt_data[:version] = plist["CFBundleShortVersionString"]
          rcpt_data[:version] ||= plist["CFBundleVersion"]
          rcpt_data[:version] ||= plist["Bundle versions string, short"]

          rcpts << rcpt_data
        end # if plist exist?

      end

      # if rcpts is empty, it could be an mpkg, which installs more than one pkg
      if rcpts.empty?
        contents_dir = info_plist = pkg_path + "Contents"
        dist_file = contents_dir.children.select{|c| c.to_s.end_with? ".dist"}[0]
        return self.receipt_data_from_xml(dist_file, pkg_path) if dist_file

        # no dist file - any other embedded packages?
        pkg_path.find do |sub_item|
          next unless sub_item.to_s =~ PKG_RE
          rcpts += self.receipt_data_from_bundle_pkg(sub_item)
        end # pkg_path.find
      end # if pkg_path.to_s.end_with? ".pkg"

      rcpts

    end # def receipt_data_from_bundle_pkg (pkg_path)

    # Parse an xml file (like a .dist, Distribution, or PackageInfo file) and find all pkg-ref or pkg-info elements
    # to extract their pkg ids and other data, or locate and recurse on any sub-pkgs.
    # Return an array of hashes of pkg data.
    # xml_file_path is a String or Pathname to the xml file. If the xml file is not
    # embedded in a pkg (eg it was extracted from a flat pkg), provide the path to the pkg as the second arg.
    #
    # Thanks to Greg Neagle for inspiration on this method from munkicommon.py
    #
    def self.receipt_data_from_xml(xml_file_path, pkg_path = nil)

      # both args must be Pathnames if they're strings
      xml_file_path = Pathname.new(xml_file_path) unless xml_file_path.is_a? Pathname
      pkg_path = Pathname.new(pkg_path) if pkg_path and !pkg_path.is_a?(Pathname)

      # this will be returned - an array of hashes of data about this pkg and sub-pkgs
      rcpts = []

      # parse the xml
      doc = REXML::Document.new(File.new(xml_file_path))

      ####
      # pkg-info elements
      doc.elements.each("//pkg-info") do |pkg_info_element|

        attribs = pkg_info_element.attributes

        # we only care about elements with both an identifier and a version
        next unless attribs["identifier"] && attribs["version"]

        data = { :apple_pkg_id => attribs["identifier"], :version => attribs["version"] }

        payload = pkg_info_element.elements.to_a('payload')[0]
        data[:installed_kb] = payload.attributes["installKBytes"].to_i if payload.attributes["installKBytes"]

        rcpts << data unless rcpts.include? data
        return rcpts unless rcpts.empty?
      end # doc.elements.each("*/pkg-ref") do |pkg|

      ####
      # pkg-ref elements
      all_ref_data = {}
      doc.elements.each("//pkg-ref") do |pkg_ref_element|

        attribs = pkg_ref_element.attributes

        next unless attribs["id"] && attribs["version"]

        # make a new hash for this pkg if needed
        this_ref_data = {:apple_pkg_id => attribs["id"]}

        # any inner-content of the element is a path to a sub-pkg
        if pkg_ref_element.text
          this_ref_data[:sub_pkg_ref] = pkg_ref_element.text

          # if its a file: url, its relative to the pkg_path
          if this_ref_data[:sub_pkg_ref] =~ /^file:.*\.pkg$/
            this_ref_data[:sub_pkg_path] = (pkg_path || xml_file_path.dirname) + URI.decode(this_ref_data[:sub_pkg_ref][5..-1])

          # but it might be a relative path from the cwd, starting with a #, which suould be ignored.
          elsif this_ref_data[:sub_pkg_ref] =~ /^#.*\.pkg$/
            this_ref_data[:sub_pkg_path] = xml_file_path.dirname + URI.decode(this_ref_data[:sub_pkg_ref][1..-1])
          end # if this_ref_data[:sub_pkg_ref] =~ /^file:.*\.pkg$/

        end # pkg_ref_element.text

        this_ref_data[:version] = attribs["version"]
        this_ref_data[:installed_kb] = attribs["installKBytes"].to_i
        this_ref_data[:auth] = attribs["auth"]

        sub_pkg_data = []

        # if we have a file path to an existing pkg, try to get data from it rather than from this xml
        if this_ref_data[:sub_pkg_path] and this_ref_data[:sub_pkg_path].exist?
          sub_pkg_data = receipt_data_from_pkg(this_ref_data[:sub_pkg_path])
        end

        # did the sub pkg have data?
        # if not, use the data from this xml, as long as we have a version
        #
        if sub_pkg_data.empty?
          if this_ref_data[:version]
            this_ref_data.delete :sub_pkg_path
            rcpts << this_ref_data
          end

        else
          # but if it did, then use the data from the sub pkg.
          rcpts += sub_pkg_data

        end # this_ref_data[:sub_pkg_path]

      end # doc.elements.each("*/pkg-ref") do |pkg_ref_element|

      # clean up each rcpt hash, subpkg ref isn't needed any more
      rcpts.each{|r| r.delete  :sub_pkg_ref }

      rcpts

    end

  end # class Package
end # module D3
