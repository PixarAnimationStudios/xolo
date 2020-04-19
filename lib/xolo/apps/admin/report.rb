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
  module Admin
    module Report
      extend self

      # TODO add report of last_usage for expirable rcpts

      #### Reports for 'd3admin report'

      # Report on all computer receipts for a given title
      def report_title_receipts (title, statuses)

        unless  Xolo::Package.all_titles.include? title
          puts "# No title '#{title}' in d3"
          return
        end

        # get the raw data
        raw_data = computer_receipts_data
        got_ea = Xolo::CONFIG.report_receipts_ext_attr_name
        if raw_data.nil? or raw_data.empty?
          puts "# No computers with receipts for '#{title}'"
          return
        end

        # json leaves status as a string
        statuses = statuses.map{|s| s.to_s}
        # this separates out the frozen filtering from the status filtering
        # statuses are OR'd,  all of them are ANDd with frozen
        # and lets us build meaningful header lines
        filter_frozen = statuses.include? "frozen"
        if filter_frozen
          statuses.delete("frozen")
          status_display = " frozen  #{statuses.join(" or ")}"
        else
          status_display = " #{statuses.join(" or ")}"
        end

        # set the title... reporting on which recipts?
        title = "All computers with#{status_display} '#{title}' receipts"

        # set the header
        if got_ea
          header = %w{Computer User patch Status As_of Frozen Installed By}
        else
          header =%w{Computer User patch Status As_of }
        end # case

        lines= []

        raw_data.each do |computer|
          next unless computer

          # skip computers without this title
          next unless computer[:rcpts] and computer[:rcpts].keys.include?(title)

          rcpt = computer[:rcpts][title]

           # if we were asked for frozen, skip rcpts not frozen
          if filter_frozen
            next unless rcpt[:frozen]
          end

          # if we were asked for certain statuses,
          # skip rcpts without that status
          unless statuses.empty?
            next unless statuses.include?  rcpt[:status]
          end

          # build a line for this rcpt
          rcpt_line = []
          rcpt_line << computer[:computer]
          rcpt_line << computer[:user]
          rcpt_line << "#{title}-#{rcpt[:version]}-#{rcpt[:revision]}"
          rcpt_line << rcpt[:status]
          rcpt_line << (computer[:as_of] ? computer[:as_of].strftime("%Y-%m-%d") : nil)

          if got_ea
             rcpt_line << (rcpt[:frozen] ? "frozen"  : "-")
             rcpt_line << (rcpt[:installed_at] ? rcpt[:installed_at].strftime("%Y-%m-%d") : nil)
             rcpt_line << rcpt[:admin]
          end #  if rcpt[:installed_at]

          lines << rcpt_line
        end # raw_data.each do |computer|

        if lines.empty?
          puts "# No#{status_display} receipts for '#{title}' were found"
        else
          D3.less_text D3.generate_report(lines.sort_by{|c| c[0]}, header_row: header, title: title)
        end # if lines emtpy?

      end # report_title_receipts (title, statuses)

      # Show a report of all current d3 rcpts on a given computer
      #
      # @param computer[String] the name of the computer to report on
      #
      # @param statuses[Array] the statuses to report on, all if empty
      #
      # @return [void]
      #
      def report_single_computer_receipts (computer_name, statuses)

        unless JSS::Computer.all_names.include? computer_name
          puts "# No computer named '#{computer_name}' in Jamf Pro"
          return
        end

        computer = JSS::Computer.new name: computer_name

        ea_name = Xolo::CONFIG.report_receipts_ext_attr_name

        # data from EA?
        if ea_name
           ea_data = computer.extension_attributes.select{|ea| ea[:name] == ea_name}.first[:value]
          if ea_data.empty?
            puts "No d3 receipts on computer '#{computer_name}'"
            return false
          elsif not ea_data.start_with?('{')
            puts "The '#{ea_name}' extention attribute data for computer '#{computer_name}' is bad"
            return false
          end # if ea_data.empty?

          rcpt_data = JSON.parse ea_data , :symbolize_names => true

        # no EA, use jamf rcpts
        else
          pkg_filenames_to_ids = Xolo::Package.all_filenames.invert
          rcpt_data = {}
          computer.software[:installed_by_casper].each do |jrcpt|
            rcpt_id = pkg_filenames_to_ids[jrcpt]
            # some might be zipped
            rcpt_id ||= pkg_filenames_to_ids[jrcpt + ".zip"]

            next unless rcpt_id
            pkg_data = Xolo::Package.package_data[rcpt_id]
            next unless pkg_data

            rcpt_data[pkg_data[:title]] = {:version =>pkg_data[:version], :revision => pkg_data[:revision], :status => pkg_data[:status]}
          end #  computer.software[:installed_by_casper].each

        end #  if ea_name ... else

        # now rcpt_data is a hash of hashes {title => { version, etc...} }

        # start building the report

        # title
        last_recon = computer.last_recon.strftime("%Y-%m-%d")
        title = "Receipts on '#{computer_name}' (user: #{computer.username}) as of #{last_recon}"

        # header...
        if ea_name
          header =  %w{patch Status As_of Frozen Installed By }
        else
          header =  %w{patch Status As_of }
        end # case

        # json leaves status as a string
        statuses = statuses.map{|s| s.to_s}
        # this separates out the frozen filtering from the status filtering
        # statuses are OR'd,  all of them are ANDd with frozen
        # and lets us build meaningful header lines
        filter_frozen = statuses.include? "frozen"
        if filter_frozen
          statuses.delete("frozen")
          status_display = " frozen #{statuses.join(" or ")}"
        else
          status_display = " #{statuses.join(" or ")}"
        end


        lines = []
        # sort by title
        rcpt_data.keys.sort.each do |title|
          rcpt = rcpt_data[title]
          # skip unwanted stati
          unless statuses.empty?
            next unless statuses.include? rcpt[:status]
          end
          # skip thawed if needed
          if filter_frozen
            next unless rcpt[:frozen]
          end
          rcpt_line = []
          rcpt_line << "#{title}-#{rcpt[:version]}-#{rcpt[:revision]}"
          rcpt_line << rcpt[:status]
          rcpt_line << computer.last_recon.strftime("%Y-%m-%d")
          if ea_name
            rcpt_line << (rcpt[:frozen] ? "frozen"  : "-")
            rcpt_line << Time.parse(rcpt[:installed_at]).strftime("%Y-%m-%d")
            rcpt_line << rcpt[:admin]
          end #  rcpt[:installed_at]
          lines << rcpt_line
        end # rcpt_data.keys.sort do |title|

        if lines.empty?
          statuses<<("frozen") if filter_frozen
          stati = statuses.empty? ? '' : " #{ statuses.join(' or ')}"
          puts "# No#{stati} receipts on '#{computer_name}'"
        else
          D3.less_text D3.generate_report lines, header_row: header, title: title
        end
      end # report_single_computer_receipts

      # Report a title in all computers' puppy queues
      #
      # @param title[String]
      #
      # @param statuses[Array<String,Symbol>]
      #
      # @return [void]
      #
      def report_puppy_queues (title, statuses)

        report_data = Report.computer_puppyq_data
        unless report_data
          puts "Reports of pending puppies require a special Extension Attribute. Please see the d3 documentation"
          return false
        end

        # json loads symbols as strings
        statuses = statuses.map{|s| s.to_s}
        status_display = " #{statuses.join(", ")}"

        title = "All computers with '#{title}' in the puppy queue"
        header = %w{Computer User patch Status Queued By As-of}
        lines = []

        report_data.each do |computer_to_report|
          this_pup = computer_to_report[:pups][title]
          # skip if we don't have this title
          next unless this_pup
          # skip unwanted statuses
          unless statuses.empty?
            next unless statuses.include? this_pup[:status]
          end
          patch = "#{title}-#{this_pup[:version]}-#{this_pup[:revision]}"
          qd_at = Time.parse(this_pup[:queued_at]).strftime "%Y-%m-%d"
          as_of = Time.parse(computer_to_report[:as_of]).strftime "%Y-%m-%d"
          lines << [computer_to_report[:computer], computer_to_report[:user], patch, this_pup[:status], qd_at, this_pup[:admin], as_of]
        end # report_data.each do |computer_to_report|
        if lines.empty?
          puts "# No computers with '#{title}' queued."
        else
          D3.less_text D3.generate_report lines, header_row: header, title: title
        end # if lines emtpy?
      end # ef puppy_installs (titles)

      # Report a single computer's puppy queue
      #
      # @param computer_name[String]
      #
      # @param statuses[Array<String,Symbol>]
      #
      # @return [void]
      #
      def report_single_puppy_queue (computer_name, statuses)
        ea_name =  Xolo::CONFIG.report_puppyq_ext_attr_name

        unless ea_name
          puts "Reports of pending puppies require a special Extension Attribute. Please see the d3 documentation"
          return false
        end

        unless JSS::Computer.all_names.include? computer_name
          puts "No computer named '#{computer_name}' in Jamf Pro"
          return false
        end

        computer = JSS::Computer.new name: computer_name
        ea_data = computer.extension_attributes.select{|ea| ea[:name] == ea_name}.first[:value]
        if ea_data.empty?
          puts "No puppies in the queue on computer '#{computer_name}'"
          return false
        elsif not ea_data.start_with?('{')
          puts "The '#{ea_name}' extention attribute data for computer '#{computer_name}' is bad"
          return false
        end

        title = "All items in the puppy queue on '#{computer_name}' (user: #{computer.username})"
        header = %w{patch Status Queued By As-of}
        lines = []
        ea_data =  JSON.parse ea_data, :symbolize_names => true

        # in json data, symbols became strings
        statuses = statues.map{|s| s.to_s}
        status_display = " #{statuses.join(", ")}"

        ea_data.each do |title,pup|
          next unless statuses.include? pup[:status]
          patch = "#{title}-#{pup[:version]}-#{pup[:revision]}"
          qa = Time.parse(pup[:queued_at]).strftime "%Y-%m-%d"
          as_of = computer.last_recon.strftime s"%Y-%m-%d"
          lines << [patch, pup[:status], qa, pup[:admin], as_of]
        end
        D3.less_text D3.generate_report lines, header_row: header, title: title

      end #report_single_puppy_queue (computer_name, statuses)


      #### Lists for d3admin walkthru

      # Show a list of all package patchs, pkg names and filenames
      # known to d3 along with their status
      #
      # @return [void]
      #
      def show_existing_package_ids
        # get them in alphabetical order
        #sorted_pkgs = Xolo::Package.package_data.values.sort{|a,b| a[:name] <=> b[:name]}
        sorted_pkgs = Xolo::Package.package_data.values.sort_by{|p| p[:name].downcase}

        # here's the columns we care about
        header = %w{ patch pkg_name filename JSS_id status}

        # map each one to an array of desired data
        lines = sorted_pkgs.map{|p|
          [ p[:patch],
            p[:name],
            Xolo::Package.all_filenames[p[:id]],
            p[:id],
            p[:status]
          ] }


        D3.less_text D3.generate_report lines, header_row: header, title: "Packages in d3"
      end

      # Show a list of all titles known to d3
      # along with the status of the most recent package with that title
      #
      # This is generally used with walkthrus.
      #
      def show_all_titles_and_patchs
        sorted_data = Xolo::Package.package_data.values.sort_by{|p| p[:patch] }

        # here's the columns we care about
        header = %w{title patch status}

        # map each one to an array of desired data
        lines = sorted_data.map{ |p| [ p[:title], p[:patch], p[:status]] }

        D3.less_text D3.generate_report lines, header_row: header, title: "titles and patchs in d3."
      end

      # Show a list of JSS package names that are NOT in d3.
      #
      # @return [void]
      def show_pkgs_available_for_import
        lines = (JSS::Package.all_names -  Xolo::Package.all_names).sort.map{|p| [p]}
        header = ['Package name']
        D3.less_text D3.generate_report lines, header_row: header, title: "JSS Packages available for importing to d3"
      end

      # Show a list of computers in the JSS, to select one for reporting
      #
      # @return [void]
      #
      def show_available_computers_for_reports
        lines = JSS::Computer.all_names.sort.map{|c| [c]}
        header = ['Computer name']
        D3.less_text D3.generate_report lines, header_row: header, title: "Computers in the JSS"
      end

      #### Lists for 'd3admin search'

      # Display a list of pkgs on the server
      #
      # @param title[String] the title of the displayed list
      #
      # @param ids[Array] an array of pkgs id's about which to
      #   display info.
      #
      # @param no_match_text[String] the text to display when there are no ids
      # @return [void]
      #
      def display_package_list (title, ids, no_match_text = "No matchings packages", show_scope = false )
        date_fmt = "%Y-%m-%d"
        header = show_scope ?  %w{ patch Status Auto_Groups Excluded_Groups } :  %w{ patch Status Added By Released By }
        lines = []
        ids.each do |pkgid|
          p = Xolo::Package.package_data[pkgid]
          next unless p
          if show_scope
            auto_gs = p[:auto_groups].empty? ? "-none-" : p[:auto_groups].join(",")
            excl_gs = p[:excluded_groups].empty? ? "-none-" : p[:excluded_groups].join(",")
            lines << [p[:patch], p[:status], auto_gs, excl_gs]
          else
            date_added = p[:added_date] ? p[:added_date].strftime(date_fmt) : "-"
            date_released = p[:release_date] ? p[:release_date].strftime(date_fmt) : "-"
            rel_by = p[:released_by] ? p[:released_by] : "-"
            lines << [p[:patch], p[:status], date_added, p[:added_by], date_released, rel_by]
          end # if show_scope
        end

        if lines.empty?
          puts no_match_text
          puts # empty line between
          return
        end
        lines.sort_by! {|l| l[0]}
        D3.less_text D3.generate_report(lines, header_row: header, title: title)
        puts # empty line between
      end # display_package_list



      # Show a list of pkgs from the d3admin 'search' action
      #
      # @param title[String] the title of pkgs to show
      #
      # @param statuses[Array<String>] only show these statuses
      #
      # @return [void]
      #
      def list_packages (title = nil , statuses = [])
        pkg_data = Xolo::Package.package_data

        if title
          title =  "All '#{title}' packages in d3"
          ids = pkg_data.values.select{|p| p[:title] == title }.map{|p| p[:id]}
        else
          title =  "All packages in d3"
          ids = pkg_data.keys
        end # if title

        unless statuses.empty?
          title +=  " with status #{statuses.join(' or ')}"
          statuses = statuses.map{|s| s.to_sym}
          status_display = " #{statuses.join(", ")}"
          ids = ids.select{|pid| statuses.include?  pkg_data[pid][:status] }
        end # if what_to_show == :all

        display_package_list title, ids, "No matching packages"

      end # def list_packages


      # Show a list of all packages with their scoped groups
      #
      # @param statuses[Array<String>] only show these statuses
      #
      # @return [void]
      #
      def list_all_pkgs_with_scope (statuses)
        title = "Group Scoping for all packages"
        title +=  " with status #{statuses.join(' or ')}" unless statuses.empty?

        if statuses.empty?
          ids = Xolo::Package.all_ids
        else
          ids = Xolo::Package.package_data.values.select{|pd| statuses.include? pd[:status].to_s }.map{|pd| pd[:id]}
        end
        Xolo::Admin::Report.display_package_list title, ids, 'No Matching Groups', :show_scope

      end

      # list packages that auto-install onto machines
      # in one or more given groups
      #
      # @param groups[String,Array<String>] the group or groups to show.
      #
      # @return [void]
      #
      def list_scoped_installs(group, statuses, scope = :auto)
        scope_text = scope == :auto ? "auto-install" : "are excluded for"
        title = "Packages that #{scope_text} for group '#{group}'"

        if JSS::ComputerGroup.all_names.include? group or Xolo::STANDARD_AUTO_GROUP == group
          ids = scope == :auto ? Xolo::Package.auto_install_ids_for_group(group) : Xolo::Package.exclude_ids_for_group(group)

          unless statuses.empty?
            title +=  " with status #{statuses.join(' or ')}"
            statuses = statuses.map{|s| s.to_sym}
            status_display = " #{statuses.join(", ")}"
            ids = ids.select{|pid| statuses.include?  Xolo::Package.package_data[pid][:status] }
          end # if what_to_show == :all

          no_match_text = "No packages #{scope_text} for group '#{group}'"
        # no such group
        else

          ids = []
          no_match_text = "No computer group named '#{group}'"
        end #  if JSS::ComputerGroup.all_names.include? group
        display_package_list title, ids, no_match_text

      end # list_scoped_installs




      #### Data gathering

      # Reconnect to both the API and DB with a much larger timeout, and
      # using an alternate DB server if one is defined. Also connect with 
      # the read-only accts, since rw isn't needed, retrieving the pws
      # requires an admin keychain, which makes automated reporting 
      # unpleasant.
      #
      # @return [Hash<String>] the hostnames of the connected JSS & MySQL servers
      #
      def connect_for_reports
        if JSS.superuser?
          jss_user = Xolo::CONFIG.client_jss_ro_user
          jss_user ||= JSS::CONFIG.api_username
          jss_pw =  Xolo::Client.get_ro_pass(:jss)

          db_user = Xolo::CONFIG.client_db_ro_user
          db_user ||= JSS::CONFIG.db_username
          db_pw = Xolo::Client.get_ro_pass(:db)

        else
          api = Xolo::Admin::Auth.rw_credentials :jss
          jss_user = api[:user]
          jss_pw =  api[:password]

          db = Xolo::Admin::Auth.rw_credentials :db
          db_user = db[:user]
          db_pw = db[:password]
        end
        D3.connect_for_reports jss_user, jss_pw, db_user, db_pw
      end # connect for report

      # Get the raw data for a client-install report, from the EA if available
      # or from the JAMF receipts if not.
      #
      # Returns an array of the report data (see
      # client_install_ea_report_data and client_install_jamf_rcpt_report_data)
      #
      # @return  [Array<Hash>] The data for doing client install reports
      #
      def computer_receipts_data
        the_data = computer_receipts_ea_data
        return the_data if the_data
        return computer_receipts_jamf_data
      end

      ### Get the latest data from the Xolo::CONFIG.report_receipts_ext_attr_name
      ### if that EA exists, nil otherwise
      ###
      ### The result is an Array of Hashes, one for each computer in Jamf Pro.
      ### Each hash contains these keys:
      ###   :computer - the name of the computer
      ###   :user - the name of the comptuer's user
      ###   :as_of - the Time when the data was gathered
      ###   :rcpts - a Hash of receipt data for the computer, keyed by basename.
      ###
      ### Each receipt in the :rcpts hash contains these keys
      ###   :version
      ###   :revision
      ###   :status
      ###   :installed_at
      ###   :admin
      ###   :frozen
      ###   :manual
      ###   :custom_expiration
      ###   :last_usage
      ###
      ### @return [Array<Hash>, nil] The data from the extension attribute, nil
      ###   if we aren't configured for the EA.
      ###
      def computer_receipts_ea_data
        return nil unless Xolo::CONFIG.report_receipts_ext_attr_name
        connect_for_reports

        ea = JSS::ComputerExtensionAttribute.new :name => Xolo::CONFIG.report_receipts_ext_attr_name

        # while we could get the data via the API by calling: result = ea.latest_values
        # but thats very slow, because it creates a temporary AdvancedSearch,
        # and retrieves it's results, and API access is always pretty slow
        # Going directly to SQL is WAY faster and since this is D3, we can.

        q = <<-ENDQ
SELECT c.computer_id, c.computer_name, c.username, c.last_report_date_epoch AS as_of, eav.value_on_client AS value
FROM computers_denormalized c
  JOIN extension_attribute_values eav
    ON c.last_report_id = eav.report_id
WHERE eav.extension_attribute_id = #{ea.id}
        ENDQ

        result = JSS::DB_CNX.db.query q

        report_data = []
        result.each_hash do |computer_ea_result|
          computer_data = {}
          computer_data[:computer] =  computer_ea_result["computer_name"].to_s
          computer_data[:user] =  computer_ea_result["username"]
          computer_data[:as_of] =  (JSS.epoch_to_time computer_ea_result["as_of"])
          rcpts ={}
          if computer_ea_result['value'].start_with? '{'
            rcpt_data = JSON.parse computer_ea_result['value'], :symbolize_names => true
            rcpt_data.each do |title, raw|
              this_r = {}
              this_r[:version] = raw[:version]
              this_r[:revision] = raw[:revision].to_i
              this_r[:status] = raw[:status]
              this_r[:installed_at] = raw[:installed_at] ? Time.parse(raw[:installed_at]) : nil
              this_r[:admin] = raw[:admin]
              this_r[:frozen] = raw[:frozen]
              this_r[:manual] = raw[:manual]
              this_r[:custom_expiration] = raw[:custom_expiration]
              this_r[:last_usage] = raw[:last_usage] ? Time.parse(raw[:last_usage]) : nil
              # the title got symbolized, so re-string it
              rcpts[title.to_s] = this_r
            end # rcpt_data.each do |title, raw|
          end # if ea_result['value'].start_with?  '{'
          computer_data[:rcpts] = rcpts
          report_data << computer_data

        end # result.each_hash do |ea_result|

        return report_data
      end # def ea_report_data

      ### get the latest receipt data from Jamf Pro's receipts table
      ### This is used if the Xolo::CONFIG.report_receipts_ext_attr_name is not set
      ### and the data it returns is less useful.
      ###
      ### The result is and Array of Hashes, one for each computer in Jamf Pro.
      ### Each hash contains these keys:
      ###   :computer - the name of the computer
      ###   :user - the name of the comptuer's user
      ###   :as_of - the Time when the data was gathered
      ###   :rcpts - a Hash of receipt data for the computer, keyed by basename.
      ###
      ### Each receipt in the :rcpts hash contains these keys
      ###   :version
      ###   :revision
      ###   :status
      ###
      ### @return [Array<Hash>] The data from the jamf receipts
      ###
      def computer_receipts_jamf_data
        q = <<-ENDQ
SELECT c.computer_name, c.username, GROUP_CONCAT(r.package_name) AS jamf_receipts, c.last_report_date_epoch AS as_of
FROM computers_denormalized c JOIN package_receipts r ON c.computer_id = r.computer_id
WHERE r.type = 'jamf'
GROUP BY c.computer_id
ENDQ

        res = JSS::DB_CNX.db.query q

        report_data = []

        pkg_filenames_to_ids = Xolo::Package.all_filenames.invert

        res.each_hash do |record|
          computer_data = {:computer => record['computer_name']}
          computer_data[:as_of] = JSS.epoch_to_time record['as_of']
          computer_data[:user] = record['username']
          computer_data[:rcpts] = {}
          record['jamf_receipts'].split(',').each do |jrcpt|

            rcpt_id = pkg_filenames_to_ids[jrcpt]
            # some might be zipped
            rcpt_id ||= pkg_filenames_to_ids[jrcpt + ".zip"]

            next unless rcpt_id
            pkg_data = Xolo::Package.package_data[rcpt_id]
            next unless pkg_data
            computer_data[:rcpts][pkg_data[:title]] = {:version =>pkg_data[:version], :revision => pkg_data[:revision], :status => pkg_data[:status]}
          end  #record['jamf_receipts'].split(',').each do
          report_data << computer_data
        end # res.each_hash do |record|
        res.free
        return report_data
      end # def jamf_rcpt_report_data

      # get the latest puppy queue data from the puppy q EA, if available.
      def computer_puppyq_data
        return nil unless Xolo::CONFIG.report_puppyq_ext_attr_name
        ea = JSS::ComputerExtensionAttribute.new :name => Xolo::CONFIG.report_puppyq_ext_attr_name
        q = <<-ENDQ
SELECT c.computer_id, c.computer_name, c.username, c.last_report_date_epoch AS as_of, eav.value_on_client AS value
FROM computers_denormalized c
  JOIN extension_attribute_values eav
    ON c.last_report_id = eav.report_id
WHERE eav.extension_attribute_id = #{ea.id}
        ENDQ

        result = JSS::DB_CNX.db.query q

        report_data = []
        result.each_hash do |ea_result|
          pups ={}
          if ea_result['value'].start_with? '{"'
            # the ea contains the full receipt YAML.
            # for now we only need this subset of it.
            pup_data = JSON.parse ea_result['value'], :symbolize_names => true
            pup_data.each do |title, raw|
              this_p = {}
              this_p[:version] = raw[:version]
              this_p[:revision] = raw[:revision].to_i
              this_p[:status] = raw[:status].to_sym
              this_p[:queued_at] = raw[:queued_at] ? Time.parse(raw[:queued_at]) : nil
              this_p[:admin] = raw[:admin]
              this_p[:custom_expiration] = raw[:custom_expiration]
              pups[title] = this_p
            end # each do r

          end # if ea_result['value'].start_with?  '{"'
          report_data << {
            :computer => ea_result["computer_name"],
            :user => ea_result["username"],
            :pups => pups,
            :as_of =>  (JSS.epoch_to_time ea_result["as_of"])
          }

        end # result.each_hash do |ea_result|

        return report_data
      end # def client_puppyq_report_data

    end # module Report
  end # module Admin
end # module Xolo
