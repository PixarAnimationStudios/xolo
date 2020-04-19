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

    # Create this package in the JSS if needed, and in d3
    #
    # @return [Integer] the JSS id of the package
    #
    def create

      # if it's already there, just return
      return @id if @in_d3

      # gotta know who did this
      raise JSS::MissingDataError, "An admin name must be set before creating this new d3 package. Use #admin= " unless @admin

      # create the JSS package if needed
      super unless @in_jss

      # who and when are we adding this pkg?
      @added_date = Time.now
      @added_by = @admin

      # change status from unsaved to pilot
      @status = :pilot

      # loop through the field definitions, and
      # use them to get data for the insert statement
      field_names = []
      sql_values = []
      P_FIELDS.each_pair do |key,field_def|
        field_names << field_def[:field_name]
        # nils and empty strings become NULL
        sql_values << (self.send(key).to_s.empty? ? 'NULL' : "'#{to_sql(key)}'")
      end # do |key,field_def


      # use the two arrays to build the SQL statement
      stmt = JSS::DB_CNX.db.prepare <<-ENDINSERT
INSERT INTO #{P_TABLE[:table_name]} (
  #{field_names.join(",\n  ")}
) VALUES (
  #{sql_values.join(",\n  ")}
)
      ENDINSERT

      # Execute it to create the record
      stmt_result = stmt.execute


      # while we're writing to the db, mark any missing packages as missing
      mark_missing_packages


      @in_d3 = true
      return @id
    end # create

    # Update this package in the JSS and in d3
    #
    # @return [Integer] the JSS id of the package
    #
    def update

      # we might be importing an existing JSS pkg to d3, which
      # means we need to create the d3 record, but the JSS record needs updating
      create if @importing and (not @in_d3)

      # update the JSS first, if needed
      super

      # and return unless we need to do something.
      return unless  @need_to_update_d3

      # Loop thru the field defs to build the SQL update statement
      new_vals = []
      P_FIELDS.each_pair do |key,field_def|

        # start builing the SET clause values, e.g. "title = 'foobar'"
        field_val = "#{field_def[:field_name]} = "

        # finish the SET clause value
        field_val << (self.send(key).to_s.empty? ? 'NULL' : "'#{to_sql(key)}'")

        # add it to the array
        new_vals << field_val
      end # do |key,field_def

      # use the new_vals array to create the update statement
      stmt = JSS::DB_CNX.db.prepare <<-ENDUPDATE
      UPDATE #{P_TABLE[:table_name]} SET
        #{new_vals.join(",  ")}
      WHERE
        #{P_FIELDS[:id][:field_name]} = #{@id}
      ENDUPDATE

      # Execute it to update the record
      stmt_result = stmt.execute

     # while we're writing to the db, mark any missing packages as missing
      mark_missing_packages

      return @id

    end # update

    # An alias for both save and update
    #
    def save
      if @in_jss
        update # this will create the d3 data if needed
      else
        create
      end
    end # save

    # Make this package the live one for its title
    #
    # @param admin[String] the name of the admin doing this.
    #
    # @return [void]
    #
    def make_live(admin = @admin)

      return :live if @status == :live

      # gotta know who did this
      raise JSS::MissingDataError, "An admin name must be set before making this d3 package live. Use the admin= method." if admin.to_s.empty?
      @admin = admin

      # who and when are we making this pkg live?
      @release_date = Time.now
      @released_by = @admin

      id_field = P_FIELDS[:id][:field_name]
      status_field = P_FIELDS[:status][:field_name]
      title_field = P_FIELDS[:title][:field_name]
      rel_date_field =  P_FIELDS[:release_date][:field_name]
      rel_by_field = P_FIELDS[:released_by][:field_name]



      # if any OLDER pkg is live for this title, make it deprecated
      q =  <<-ENDUPDATE
      UPDATE #{P_TABLE[:table_name]}
        SET #{status_field} = '#{P_FIELDS[:status][:to_sql].call(:deprecated)}'
      WHERE #{title_field} = '#{to_sql :title}'
        AND  #{status_field} = '#{P_FIELDS[:status][:to_sql].call(:live)}'
        AND  #{id_field} < '#{to_sql(:id)}'
      ENDUPDATE
      stmt = JSS::DB_CNX.db.prepare q
      stmt_result = stmt.execute

      # now make any older pilot pkgs for this title :skipped
      q =  <<-ENDUPDATE
      UPDATE #{P_TABLE[:table_name]}
        SET #{status_field} = '#{P_FIELDS[:status][:to_sql].call(:skipped)}'
      WHERE #{title_field} = '#{to_sql :title}'
        AND  #{id_field} < #{to_sql(:id)}
        AND  #{status_field} = '#{P_FIELDS[:status][:to_sql].call(:pilot)}'
      ENDUPDATE
      stmt = JSS::DB_CNX.db.prepare q
      stmt_result = stmt.execute


      #  any NEWER pkgs for this title, become pilot (perhaps again)
      #  This is for when we re-enliven an old pkg
      q =  <<-ENDUPDATE
      UPDATE #{P_TABLE[:table_name]}
        SET #{status_field} = '#{P_FIELDS[:status][:to_sql].call(:pilot)}'
      WHERE #{title_field} = '#{to_sql :title}'
        AND  #{id_field} > '#{to_sql(:id)}'
      ENDUPDATE
      stmt = JSS::DB_CNX.db.prepare q
      stmt_result = stmt.execute

      # now make this pkg live
      @status = :live
      q =  <<-ENDUPDATE
      UPDATE #{P_TABLE[:table_name]} SET
        #{status_field} = '#{to_sql :status}',
        #{rel_by_field} = '#{to_sql :released_by}',
        #{rel_date_field} = '#{to_sql :release_date}'
      WHERE #{id_field} = #{@id}
      ENDUPDATE
      stmt = JSS::DB_CNX.db.prepare q
      stmt_result = stmt.execute

      # update our knowledge of the world
      self.class.package_data :refresh

      # while we're writing to the db, mark any missing packages as missing
      mark_missing_packages

      puts "Done '#{patch}' is now live."

      # auto_clean if we should
      auto_clean(admin) if D3::CONFIG.admin_auto_clean

      # run any post-make-live script if needed
      run_make_live_script

    end # make live

    # Add or replace a pre- or post- script for this package.
    #
    # This adds a new script to the JSS, and the sets this package to
    # use it.
    #
    # If the desired script already exists in the JSS, use an appropriate setter method:
    # {#pre_install_script_id=}, {#post_install_script_id=}, {#pre_remove_script_id=}, {#post_remove_script_id=},
    # {#pre_install_script_name=},{#post_install_script_name=}, {#pre_remove_script_name=}, {#post_remove_script_name=}
    #
    # @param args[Hash]
    #
    # @option args :script_type[Symbol] which script to set? One of :pre_install, :post_install, :pre_remove, :post_remove
    #
    # @option args :source[String,Pathname] the script code, or a full path to a file containing the script code.
    #   If the value is a String and doesn't start with a /, it's considered to be the script code.
    #
    # @option args :script_name[String] the name of the new script in the JSS. Defaults to "<title>-d3<script_type>-YYYYmmddHHMMSS"
    #
    # @option args :script_category[String] the name of the JSS category for this script. Defaults to the value of D3:Package::DFT_SCRIPT_CATEGORY
    #
    # @option args :delete_current[Boolean] if this new script is replacing one for this pkg, should the old one be deleted from the JSS?
    #
    # @return [Integer] the id of the newly created JSS::Script.
    #
    def new_script (args = {})

      raise JSS::InvalidDataError, ":script_type must be one of :#{SCRIPT_TYPES.join(', :')}" unless SCRIPT_TYPES.include? args[:script_type]

      args[:script_category] ||= D3::CONFIG.jss_default_script_category
      if args[:script_category]
        raise JSS::NoSuchItemError, "No such category '#{args[:script_category]}' in the JSS." unless JSS::Category.all_names.include? args[:script_category]
      end

      args[:script_name] ||= "#{@title}-d3#{args[:script_type]}-#{Time.now.strftime('%Y%m%d%H%M%S')}"

      file_source = nil

      file_source = case args[:source]
      when Pathname
        args[:source]
      when String
        Pathname.new(args[:source]) if args[:source].start_with? "/"
      else
        raise JSS::InvalidDataError, ":source must be a full path (Pathname or String), or a String containing the script code."
      end # case

      if file_source
        raise JSS::MissingDataError, "The file #{file_source} is missing or unreadable." unless file_source.readable?
        code = file_source.read
      else
        code = args[:source]
      end

      # get the new script into the JSS
      script = JSS::Script.new :id => :new, :name => args[:script_name]
      script.contents = code
      script.category = args[:script_category]
      new_script_id = script.save

      # update our knowledge of all JSS scripts so the next steps don't fail.
      JSS::Script.all :refresh

      case args[:script_type]
        when :pre_install
          old_script_id = pre_install_script_id
          self.pre_install_script_id = new_script_id
        when :post_install
          old_script_id = post_install_script_id
          self.post_install_script_id = new_script_id
        when :pre_remove
          old_script_id = pre_remove_script_id
          self.pre_remove_script_id = new_script_id
        when :post_remove
          old_script_id = post_remove_script_id
          self.post_remove_script_id = new_script_id
      end

      # delete the old?
      if args[:delete_current] and old_script_id
        JSS::Script.new(:id => old_script_id).delete if JSS::Script.all_ids.include? old_script_id
      end

      new_script_id
    end # new_script

    # Perform any auto_cleanup, if the config says we should
    #
    # @param admin[String] the admin doing the make-live
    #
    # @return [void]
    #
    def auto_clean  (admin)

      # safety
      return unless D3::CONFIG.admin_auto_clean

      puts "Starting auto-clean of old packages for '#{@title}'"

      ## First the deprecated pkgs

      # the id's of the deprecated pkgs for this title, in numerical order
      # the last ones are the newest.
      deprecated_ids = D3::Package.deprecated_data.values.select{|dp| dp[:title] == @title}
      deprecated_ids.map!{|dp| dp[:id] }.sort!

      # keeping any?
      number_deprecated_to_keep = D3::CONFIG.admin_auto_clean_keep_deprecated
      number_deprecated_to_keep ||= 0

      puts "Keeping #{number_deprecated_to_keep} deprecated packages."

      # 'pop' pulls them off the end
      deprecated_ids_to_keep = []
      number_deprecated_to_keep.times{ deprecated_ids_to_keep << deprecated_ids.pop  }
      deprecated_ids_to_keep.compact!

      # delete them if we should
      deprecated_ids.each do |id|
        next if deprecated_ids_to_keep.include? id
        victim = D3::Package.new(:id => id)
        victim.delete(
          admin: admin,
          keep_scripts: false,
          keep_in_jss: false,
          rwpw: D3::Admin::Auth.rw_credentials(:dist)[:password]
        )
        puts "Deleted deprecated package: #{victim.patch}, id:#{victim.id}, filename: #{victim.filename}."
      end

      ## then the skipped pkgs

      skipped_ids = D3::Package.skipped_data.values.select{|sp| sp[:title] == @title}
      skipped_ids.map!{|sp| sp[:id] }.sort!

      # keep the ones newer than the just-deprecated pkg?
      if D3::CONFIG.admin_auto_clean_keep_latest_pilots
        deprecated_ids = D3::Package.deprecated_data(:refresh).values.select{|dp| dp[:title] == @title}
        deprecated_ids.map!{|dp| dp[:id] }
        just_deprecated = deprecated_ids.max
        just_deprecated ||= 0
        skipped_ids_to_keep = skipped_ids.select{|id| id > just_deprecated }
        puts "Keeping most recent pilot packages as skipped."
      # no, delete them all
      else
        skipped_ids_to_keep  = []
        puts "Not keeping any pilot or skipped packages."
      end

      # delete them if we should
      skipped_ids.each do |id|
        next if skipped_ids_to_keep.include? id
        victim = D3::Package.new(:id => id)
        victim.delete(
          admin: admin,
          keep_scripts: false,
          keep_in_jss: false,
          rwpw: D3::Admin::Auth.rw_credentials(:dist)[:password]
        )
        puts "Deleted skipped package: #{victim.patch}, id:#{victim.id}, filename: #{victim.filename}."
      end
      puts "Finished auto-clean of old packages for '#{@title}'"
      return true
    end

    # Delete this package from d3, possibly leaving it in the JSS
    #
    # @param keep_in_jss[Boolean] should we keep the JSS package around? defaults to false
    #
    # @param keep_scripts[Boolean] should the related scripts be kept in the JSS?
    #
    # @param admin[String] who's doing this?
    #
    # @param rwpw[String] the read-write for the master distr. point
    #
    # @return [Array<String>] a textual list of scripts delted and not
    #   deleted because they're in use by other d3 pkgs or casper policies
    #    (empty if keep_scripts is true)
    #
    def delete (keep_in_jss: false, keep_scripts: false, admin: @admin, rwpw: nil)

      unless keep_in_jss
        # raise an exception if any polcies are using this pkg.
        pols = policy_ids
        unless pols.empty?
          names = pols.map{|pid| JSS::Policy.map_all_ids_to(:name)[pid]}.join(', ')
          raise JSS::UnsupportedError, "Can't delete package from JSS, used by these policies: #{names} "
        end # unless pols.empty
      end # unles keep in jss

      # use @ admin if its defined and needed
      admin ||= @admin

      # delete scripts or not?  the result is an array of what happened.
      script_actions = keep_scripts ? [] : delete_pkg_scripts

      # delete it from the pakcages table
      stmt = JSS::DB_CNX.db.prepare "DELETE FROM #{P_TABLE[:table_name]} WHERE #{P_FIELDS[:id][:field_name]} = '#{@id}'"
      stmt_result = stmt.execute

      @status = :deleted

      # delete it from the JSS unless asked not to
      unless keep_in_jss
         super delete_file: true, rw_pw: rwpw, unmount: false
      end

     # while we're writing to the db, mark any missing packages as missing
      mark_missing_packages

      # update our knowledge of the world
      D3::Package.package_data :refresh

      return script_actions
    end

    # Learn the apple package id's installed by this pkg by
    # querying the package on the current dist. point. This is primarily used
    # for importing or repairing packages already on the server.
    #
    # When adding new packages, the {#upload_master_file} method will query the
    # data before uploading the file.
    #
    #
    # @param dist_pw[String] the read-only or read-write password for the dist. point for this machine
    #
    # @param unmount[Boolean] should the dist.point be unmounted when done?
    #
    # @return [void]
    #
    def update_apple_receipt_data(dist_pw, unmount = true)
      return nil if @filename.end_with? ".dmg"
      raise JSS::NoSuchItemError, "Please create this package on the server before updating the Apple receipt data" unless @in_jss

      mdp = JSS::DistributionPoint.my_distribution_point
      raise JSS::MissingDataError, "Missing :dist_pw for distrib. point '#{mdp.name}'" unless dist_pw

      # try the passwd both with ro and rw
      begin
        mnt_path = mdp.mount(dist_pw, :ro)
      rescue JSS::InvalidDataError
        mnt_path = mdp.mount(dist_pw, :rw)
      end

      pkg_path = mnt_path + JSS::Package::DIST_POINT_PKGS_FOLDER + @filename
      raise JSS::NoSuchItemError, "Package file #{@filename} doesn't exist on the current dist. point." unless pkg_path.exist?

      pkg_to_query = pkg_path

      # do we need to unzip a bundle pkg?
      if @filename.end_with? ".zip"
        work_dir = Pathname.new Dir.mktmpdir
        unless system "/usr/bin/unzip -qq -o -d #{Shellwords.escape work_dir.to_s} #{Shellwords.escape pkg_path.to_s}"
          raise RuntimeError, "Failed to unzip bundle pkg #{@filename}"
        end #system
        pkg_to_query = work_dir +  @filename.sub(/\.zip$/, '')
        cleanup_work_dir = true
      end # if @filename.end_with? ".zip"

      @apple_receipt_data = D3::Package.receipt_data_from_pkg(pkg_to_query)
      @need_to_update_d3 = true unless @initializing
      work_dir.rmtree if cleanup_work_dir
      mdp.unmount if unmount
    end # update_apple_receipt_data


    # Mark missing packages as so on the server
    #
    # This should run any time we write to the d3_packages table
    #
    # @return [void]
    def mark_missing_packages
      missing_ids = self.class.missing_data.keys
      unless missing_ids.empty?
        q =  <<-ENDUPDATE
        UPDATE #{P_TABLE[:table_name]}
          SET #{ P_FIELDS[:status][:field_name]} = '#{P_FIELDS[:status][:to_sql].call(:missing)}'
        WHERE #{P_FIELDS[:id][:field_name]} IN (#{missing_ids.join(',')})
        ENDUPDATE
        stmt = JSS::DB_CNX.db.prepare q
        stmt_result = stmt.execute
      end # unless empty
    end # mark missing pkgs

    # Upload a locally-readable file to the master distribution point.
    # If the file is a directory (like a bundle .pk/.mpkg) it will be zipped before
    # uploading and the @filename will be adjusted accordingly
    #
    # If you'll be uploading several files you can specify unmount as false, and do it manually when all
    # are finished with JSS::DistributionPoint.master_distribution_point.unmount
    #
    # This method is mostly performed by the parent class, see {JSS::Package.upload_master_file}.
    # Before calling super, this method populates @apple_receipt_data with info
    # from the local file.
    #
    # @param local_file_path[String,Pathname] the local path to the file to be uploaded
    #
    # @param rw_pw[String,Symbol] the password for the read/write account on the master Distribution Point,
    #   or :prompt, or :stdin# where # is the line of stdin containing the password See {JSS::DistributionPoint#mount}
    #
    # @param unmount[Boolean] whether or not ot unount the distribution point when finished.
    #
    # @return [void]
    #
    def upload_master_file (local_file_path, rw_pw, unmount = true)
      raise JSS::NoSuchItemError, "Please create this package in d3 before uploading it." unless @in_d3
      if local_file_path.to_s =~ PKG_RE
        @apple_receipt_data = D3::Package.receipt_data_from_pkg(local_file_path)
        @need_to_update_d3 = true
      end # if local_file_path.to_s =~ PKG_RE
      super
      update
    end

    # Create, or re-create, the BOM index records for this
    # Package in the JSS Database.
    #
    # This is the equivalent of clicking the "index" button
    # in Casper Admin.app, and is necessary for Casper to
    # be able to uninstall items. It can only happen after the
    # item has already been saved to the JSS and has an
    # id in the database.
    #
    # @param args[Hash]  The arguments for the method
    #
    # @option args :local_filepath[String,Pathname] the path
    #   to a local copy of the installer pkg/dmg
    #
    # @option args :ro_pw[String] the read-only password
    #   for the AFP/SMB share of the master distribution point.
    #
    # @return [void]
    #
    def mk_index(args = {})

      raise JSS::NoSuchItemError, "Please create this package in the JSS before indexing it." unless @in_jss
      raise JSS::InvalidConnectionError, "Indexing a package requires a database connection. Use JSS::DB_CNX.connect" unless JSS::DB_CNX.connected?

      if args[:local_filepath]
        file_to_index = Pathname.new(args[:local_filepath])

      elsif args[:ro_pw]
        mdp = JSS::DistributionPoint.master_distribution_point
        file_to_index = mdp.mount(args[:ro_pw], :ro) +"#{DIST_POINT_PKGS_FOLDER}/#{@filename}"
        if file_to_index.to_s.end_with? ".zip"
          tmpdir = Pathname.new "/tmp/jss-tmp-#{$$}"
          system "/usr/bin/unzip '#{thing_to_index}' -d '#{tmpdir}'"
          file_to_index = tmpdir + file_to_index.title.to_s.sub(/.zip$/, '')
        end

      else
        raise JSS::InvalidDataError, "Need a :local_filepath or :ro_pw"
      end

      # get the index data
      # is it an (m)pkg?
      if file_to_index.to_s =~ /\.m?pkg$/
        bom_lines = ''

        # if the thing is a pkg bundle, find and read all the bom files it contains
        if (file_to_index + "Contents").directory?
          (file_to_index + "Contents").find do |path|
            bom_lines += `echo; /usr/bin/lsbom -p fugTsMc '#{path}'` if path.to_s =~ /\.bom$/
          end # do path

        else
          # else its a flat file - so do it using pkgutil
          bom_files = `/usr/sbin/pkgutil --bom '#{file_to_index}'`
          bom_files.split("\n").each do |file|
            bom_lines += `/usr/bin/lsbom -p fugTsMc '#{file}'`
          end
        end # .directory?

      elsif file_to_index.to_s =~ /\.dmg$/

        # if its a .dmg, mount it, make a tmp bom file, and read that
        mnt_line =  `/usr/bin/hdiutil attach -readonly -nobrowse -noautoopen -owners on '#{file_to_index}'`.lines.last
        mnt_point = Pathname.new mnt_line.split("\t").last.chomp
        raise FileServiceError, "There was a problem mounting the image #{file_to_index}" unless mnt_point.mountpoint?

        tmp_bom = "/tmp/#{@filename}.#{$$}.bom"
        system "/usr/bin/mkbom '#{mnt_point}' '#{tmp_bom}'"
        bom_lines = `/usr/bin/lsbom -p fugTsMc '#{tmp_bom}'`

        system "/usr/bin/hdiutil detach '#{mnt_point}'"
        system "rm -rf '#{tmp_bom}'"

      else
        raise JSS::InvalidDataError, "#{@filename} doesn't looks like a .pkg or .dmg. Try Casper Admin to index it."
      end # if filename .pkg

      # If there are no bomlines (perhaps a payloadless pkg?) just return
      return true if bom_lines.empty?

      # split the bom lines
      index_records = bom_lines.split "\n"

      # reset our  lists of files
      @index = []
      @file_list = []

      # the start of the SQL insert statement
      insert_stmt = "INSERT INTO package_contents (package_id,file,owner_name,group_name,modification_date,size,mode,checksum) VALUES"
      insert_vals = []

      # loop through the bom data and make a new record for each line
      index_records.each do |line|
        next if line.empty?

        #break out the data for each item
        (path,uid,gid,modtime,size,mode,checksum) = line.split "\t"

        # if the path is just a dot (usually the first one)
        # make it a /
        if path == "."
          clean_path = "/"
        elsif path.start_with? "."
          clean_path = path.sub ".", ""
        else
          clean_path = path
        end

        # rebuild our local lists of files
        @index << { 'path' => clean_path,
        'uid' => uid,
        'gif' => gid,
        'modtime' => modtime,
        'size' => size,
        'mode' => mode }

        @file_list << clean_path unless mode.start_with? "d"

        # JSS stores modtime as string w/o the weekday
        modtime.gsub!(/^(Sun|Mon||Tue|Wed|Thu|Fri|Sat) /, '') if defined? modtime

        insert_vals << "('#{@id}','#{Mysql.quote clean_path}','#{uid}','#{gid}','#{modtime}','#{size}','#{mode}','#{checksum}')"

      end # do line

      # first delete any existing index records for this pkg
      stmt = JSS::DB_CNX.db.prepare "DELETE FROM #{PKG_CONTENTS_TABLE} WHERE package_id = #{@id}"
      stmt_result = stmt.execute

      # now insert the new values
      stmt = JSS::DB_CNX.db.prepare(insert_stmt + " " + insert_vals.join(','))
      stmt_result = stmt.execute

      # while we're writing to the db, mark any missing packages as missing
      mark_missing_packages

      return true
    end #mk_index

  end # class Package
end # module D3
