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

  # client/lists.rb
  #
  # Methods related to the display of lists via the d3 client tool
  #


  class Client < JSS::Client

    # list installed d3 items.
    # The arg can be used to limit what's listed
    # and can be one of :all, :manual, :pilot, :frozen.
    # (anything other than :manual, :pilot, or :frozen
    # is treated as :all)
    #
    # @param what_to_list[Symbol] one of :all, :manual, :pilot, :frozen.
    #   defaults to :all
    #
    # @return [void]
    #
    def self.list_installed (what_to_list = :all)

      case what_to_list
        when :manual then
          title = "Manually installed packages (not-uninstallable<, frozen^)"
          kind = "manually installed "
        when :pilots then
          title = "Packages being piloted on this machine (not-uninstallable<, frozen^)"
          kind = "pilot "
        when :frozen then
          title = "Packages frozen on this machine (not-uninstallable<)"
          kind = "frozen "
       else
          title = "All packages installed by d3 (not-uninstallable<, frozen^)"
          kind = ""
     end # case show

      colheaders = %w{title Vers-Rev Status Installed By}

      lines = []

      Xolo::Client::Receipt.all.keys.sort.each do |bn|

        # its a d3 installer
        rcpt = Xolo::Client::Receipt.all[bn]

        if what_to_list == :manual
          next unless rcpt.manual?
        end # if manual

        if what_to_list == :pilots
          next unless rcpt.pilot?
        end

        if what_to_list == :frozen
          next unless rcpt.frozen?
        end

        title = rcpt.title
        title += "<" unless rcpt.removable?
        title += "^" if rcpt.frozen? and (not what_to_list == :frozen)
        date = rcpt.installed_at.strftime "%Y-%m-%d"

        lines << [title, "#{rcpt.version}-#{rcpt.revision}", rcpt.status, date, rcpt.admin]

      end # installed_pkgs.each

      if lines.empty?
        puts "No #{kind}receipts on this computer"
      else
        D3.less_text D3.generate_report(lines, :title => title, :header_row => colheaders)
      end
    end # list_all_installed

    #  list all manually installed pkgs
    #
    def self.list_manual
      self.list_installed  :manual
    end

    #  list all installed pilots
    #
    def self.list_pilots
      self.list_installed :pilots
    end

    #  list all frozen pkgs
    #
    def self.list_frozen
      self.list_installed :frozen
    end

    # list_pending_puppies
    #
    def self.list_pending_puppies
      if  Xolo::PUPPY_Q.q.empty?
        puts "# There are no puppies in the queue"
        return nil
      end

      title = "Puppy packages awaiting logout"
      colheaders = %w{patch Status Queued-at By}
      lines = []

      # loop through the puppies in the queue
      Xolo::PUPPY_Q.q.values.each do | pup|
        lines << [pup.patch, pup.status, (pup.queued_at.strftime "%b %d %Y %H:%M:%S"), pup.admin]
      end # do pup
      D3.less_text D3.generate_report(lines, :title => title, :header_row => colheaders)

    end # list pending pups

    # list currently available packages to stdout via 'less'
    #
    # @return [void]
    #
    def self.list_available(force = false)

      # If using force, show all live pkgs
      if force or D3.forced?
        ids_to_show = Xolo::Package.live_ids
        title = "All live packages in d3 (* = installed, ^ = puppies)"

      # otherwise, only those available to this machine based on
      # excluded_groups.
      # (the intersection of all live, with all available to this machine,
      # the latter of which includes non-live)
      else
        ids_to_show = Xolo::Package.live_ids & Xolo::Client.available_pkg_ids
        title = "Live packages available for this machine (* = installed, ^ = puppies)"
      end # if force

      header = ["title", "Vers-Rev" , "Auto-installed on" ]

      my_rcpt_ids = Xolo::Client::Receipt.all.values.map{|r| r.id}

      lines = []
      ids_to_show.each do |id|
        pkg = Xolo::Package.package_data[id]
        bn = pkg[:title]
        bn += "*" if my_rcpt_ids.include? id
        bn += "^" if pkg[:reboot]
        auto_grps = pkg[:auto_groups].empty? ? "-" : pkg[:auto_groups].join(',')
        lines << [bn, "#{pkg[:version]}-#{pkg[:revision]}", auto_grps ]
      end
      lines.sort_by! {|l| l[0]}
      D3.less_text D3.generate_report(lines, header_row: header, title: title)

      return true

    end # list_avail

    # list the files installed by one or more installers
    #
    def self.list_files(pkgs)
      self.connect_for_reports
      pkgs.each do |pkg_to_match|
        begin
          found_pkg = Xolo::Package.find_package pkg_to_match
          unless found_pkg
            puts "Skipping '#{pkg_to_match}': no matching patch in d3"
            next
          end
          puts "Querying for files installed by '#{found_pkg.patch}'..."

          # because this is just a list of single strings
          # and doesn't need column formatting,
          # and mostly because it can be tens of thousands
          # of lines long, we're not using 'generate_report"
          # and just building a huge string to display.
          file_list = "# Files installed by #{found_pkg.patch}\n"
          file_list += "#==========================================================================\n"
          file_list += found_pkg.installed_files.join("\n")

          D3.less_text file_list

        rescue JSS::MissingDataError, JSS::InvalidDataError
          D3.log "Skipping #{item_to_match}:\n   #{$!}", :error
          D3.log_backtrace
        end # begin
      end # isntallers.each
    end # list files

    # find out which patchs install one or more given files
    #
    def self.query_files (paths)
      self.connect_for_reports
      paths.each do |path|
        puts "Querying for packages that install '#{path}'..."
        path = path.chomp "/"  # remove trailing slashes on dirs
        query = <<-ENDQ
        SELECT pkgs.package_id
        FROM #{Xolo::Package::P_TABLE[:table_name]} pkgs
        JOIN #{Xolo::Package::PKG_CONTENTS_TABLE} contents
        ON pkgs.#{Xolo::Package::P_FIELDS[:id][:field_name]} = contents.#{Xolo::Package::P_FIELDS[:id][:field_name]}
        WHERE contents.file = '#{Mysql.quote path}'
        ENDQ
        search_results = JSS::DB_CNX.db.query query
        ids = []
        search_results.each{|id| ids << id[0].to_i}
        search_results.free
        if ids.empty?
          puts "# Nothing in d3 installs '#{path}'"
        else
          title = "Packages that install '#{path}'"
          colheader = %w{patch Status Installed}
          lines = []
          ids.each do |id|
            begin
              pkg = Xolo::Package.new id: id
              lines << [pkg.patch, pkg.status.to_s, (pkg.installed? ? "yes" : "no")]
            rescue
              D3.log "Couldn't get pkg for id #{id}", :error
            end # begin
          end
          D3.less_text D3.generate_report(lines, header_row: colheader, title: title)

        end # if ids.empty?
      end # paths each path
    end # def query files

    # Display the details about one or more pkgs and/or receipts on the local machine
    #
    # @param pkgs[String,Array<String>] the pkgs to list details for.
    #
    # @return [void]
    #
    def self.list_details(pkgs)
      pkgs = [pkgs] if pkgs.is_a? String
      pkgs.each do |item_to_match|
        begin

          # package details
          server_pkg =  Xolo::Package.find_package(item_to_match)
          if server_pkg
            puts "# Found package on the server matching '#{item_to_match}'\n"
            puts server_pkg.formatted_details
          else
            puts "# No package on the server matched '#{item_to_match}'"
            puts "#   (doesn't exist, or title has no live patchs)"
          end

          # receipt details
          rcpt  = Xolo::Client::Receipt.find_receipt item_to_match
          if rcpt
            puts
            if server_pkg
              if rcpt.patch == server_pkg.patch
                puts "# Found matching receipt for patch '#{server_pkg.patch}'\n"
              else
                puts "# Found receipt for different patch: '#{rcpt.patch}'\n"
              end # if rcpt.patch == server_pkg.patch

            else # no svr pkg
              puts "# Found receipt matching '#{item_to_match}'\n"
            end # if svr pkg

            puts rcpt.formatted_details

          else # no rcpt
            puts "# No receipt matched '#{item_to_match}'"
          end # if rcpt

        rescue
          D3.log "An error occured getting the details of #{item_to_match}:\n   #{$!}", :error
          D3.log_backtrace
          next
        end # begin

      end # args.each
    end # list details

    # Reconnect to both the API and DB with a much larger timeout, and
    # using an alternate DB server if one is defined.
    #
    # @return [Hash<String>] the hostnames of the connected JSS & MySQL servers
    #
    def self.connect_for_reports
      jss_ro_user = Xolo::CONFIG.client_jss_ro_user
      jss_ro_user ||= JSS::CONFIG.api_username

      db_ro_user = Xolo::CONFIG.client_db_ro_user
      db_ro_user ||= JSS::CONFIG.db_username

      D3.connect_for_reports  jss_ro_user, get_ro_pass(:jss), db_ro_user, get_ro_pass(:db)
    end # connect for report

  end # class
end # module Xolo

