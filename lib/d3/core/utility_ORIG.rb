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

  # Is there a process running that would prevent un/installation?
  #
  # @return [Boolean]
  #
  def self.prohibited_by_process_running?(xprocs)
    # this is needed in case saved rcpts have nil or a string instead
    # of an array, from pre v3.0.12
    xprocs = JSS.to_s_and_a(xprocs)[:arrayform]
    processes = `/bin/ps -A -c -o comm`.split("\n")
    current_prohibiting = processes & xprocs
    return true unless current_prohibiting.empty?
  end

  # Try to figure out the login name of the admin running this code
  #
  # @return [String] an admin name.
  #
  def self.admin
    no_good = badmins

    # use the USER if it's valid
    admin = ENV['USER']

    # otherwise, try SUDO_USER
    admin = ENV['SUDO_USER'] if no_good.include? admin

    # otherwise, try SSH_CLIENT_USER
    admin = ENV['SSH_CLIENT_USER'] if no_good.include? admin

    # otherwise, use the default, which might still be bad
    admin = DFT_CLI_ADMIN if no_good.include? admin

    admin
  end # get admin name

  # The list of names not allowed as the --admin option in d3
  #
  # This just combines DISALLOWED_ADMINS and
  # D3::CONFIG.client_prohibited_admin_names
  #
  # @return [Array] list of admins not allowed.
  #
  def self.badmins
    return D3::DISALLOWED_ADMINS unless D3::CONFIG.client_prohibited_admin_names
    D3::DISALLOWED_ADMINS + D3::CONFIG.client_prohibited_admin_names
  end

  # Run a Casper policy on the local machine
  #
  # @param policy[String,Integer] the custom-trigger, name, or id of the policy
  #
  # @param type[Symbol] the type of policy being run, e.g. :expiration
  #
  # @param verbose[Boolean] should we be verbose?
  #
  # @return [boolean] Did the policy run?
  #
  def self.run_policy(policy, type, verbose = false)
    D3.log "Running #{type} policy", :info

    # if numeric, and there's a policy with that id
    if policy =~ /^\d+$/ && (polname = JSS::Policy.map_all_ids_to(:name)[policy])
      D3.log "Executing #{type} policy '#{polname}', id: #{policy}", :debug
      pol_to_run = "-id #{policy}"

    # if there's a policy with that name
    elsif polid = JSS::Policy.map_all_ids_to(:name).invert[policy]
      D3.log "Executing #{type} policy '#{policy}', id: #{polid}", :debug
      pol_to_run = "-id #{polid}"

    # else assume its a trigger
    else
      D3.log "Executing #{type} policy with trigger '#{policy}'", :debug
      pol_to_run = "-event '#{policy}'"
    end

    output = JSS::Client.run_jamf 'policy', pol_to_run, verbose
    if D3::LOG.level == :debug
      D3.log 'Policy execution output:', :debug
      output.lines.each { |l| D3.log "  #{l.chomp}", :debug }
    end

    if output.include? 'No policies were found for the'
      D3.log "No policy matching '#{policy}' was found in the JSS", :warn
      return false
    else
      D3.log "Done executing #{type} policy", :debug
      return true
    end
  end # run policy

  # Get the ids of all scripts used by all policies
  # This is a hash of PolicyName => Array of Script id's
  #
  # @return [Hash{String => Array<Integer>}]
  #
  def self.policy_scripts
    qry = <<-ENDQ
    SELECT p.name, GROUP_CONCAT(ps.script_id) AS script_ids
    FROM policies p
    JOIN policy_scripts ps
      ON p.policy_id = ps.policy_id
    GROUP BY p.policy_id
    ENDQ
    res = JSS::DB_CNX.db.query qry
    p_scripts = {}
    res.each { |r| p_scripts[r[0]] = r[1].split(/,\s*/).map(&:to_i) }
    p_scripts
  end

  # Generate a report of columned data, either fixed-width or tab-delimited.
  # The title line(s) are pre-pended with '# ' for easier exclusion when using
  # the report as input for some other program. If the :type is :fixed, so
  # will the column header line.
  #
  # @param lines[Array<Array>] the rows and columns of data
  #
  # @param type[Symbol] :fixed or :tab, defaults to :fixed
  #
  # @param args[Hash] the options for the report
  #
  # @options args :title[String] a descriptive text or title, shown above the
  #   column headers. Every line is pre-pended with '# '.
  #   Only used on :fixed reports.
  #
  # @option args :header_row[Array<String>,nil] the column headers. optional.
  #
  # @return [String] the formatted report.
  #
  def self.generate_report(lines, type: :fixed, header_row: [], **args)
    raise JSS::InvalidDataError, 'The first argument must be an Array of Arrays' unless lines.is_a? Array
    raise JSS::InvalidDataError, 'The header_row must be an Array' unless header_row.is_a? Array

    return '' if lines.empty?

    # tab delim is easy
    if type == :tab
      report_tab = header_row.join("\t")
      lines.each { |line| report_tab += "\n#{line.join("\t")}" }
      return report_tab.strip
    end # if :tab

    # below here, fixed width
    format = ''
    line_width = 0
    header_row[0] = "# #{header_row[0]}"

    col_widths(lines, header_row).each do |w|
      # make sure there's a space between columns
      col_width = w + 1

      # add the column to the printf format
      format += "%-#{col_width}s"
      line_width += col_width
    end
    format += "\n"

    # limit the total line width for the header the width of the terminal
    if IO.console
      height, width = IO.console.winsize
      line_width = width if line_width > width
    else
      line_width = 80
    end

    # title if given
    report = args[:title] ? "# #{args[:title]}\n" : ''

    unless header_row.empty?
      raise JSS::InvalidDataError, "Header row must have #{lines[0].count} items" unless header_row.count == lines[0].count
      # then the header line if given
      report +=  format % header_row
      # add a separator
      report +=  '#' + ('-' * (line_width - 1)) + "\n"
    end
    # add the rows
    lines.each { |line| report += format % line }

    report
  end # generate report

  # Given an Array of Arrays representing rows and columns of data
  # figure out the widest width of each column and return an array
  # of integers representing those widths
  #
  # @param data_array[Array<Array>] The rows and columns of data
  #
  # @param header_row[Array] An optional header row to include in the
  #   width calculation.
  #
  # @return [Array<Integer>] the max widths of each column of data.
  #
  def self.col_widths(data, header_row = [])
    widths = header_row.map { |c| c.to_s.length }
    data.each do |row|
      row.each_index do |col|
        this_width = row[col].to_s.length
        widths[col] = this_width if this_width > widths[col].to_i
      end # do field
    end # do line
    widths
  end

  # Send a string to the terminal, possibly piping it through 'less'
  # if the number of lines is greater than the number of terminal lines
  # minus 3
  #
  # @param text[String] the text to send to the terminal
  #
  # @param show_help[Boolean] should the text have a line at the top
  #   showing basic 'less' key commands.
  #
  # @result [void]
  #
  def self.less_text(text, show_help = true)
    unless IO.console
      puts text
      return
    end

    height, width = IO.console.winsize

    if text.lines.count <= (height - 3)
      puts text
      return
    end

    if show_help
      help = "#------' ' next, 'b' prev, 'q' exit, 'h' help ------"
      text = "#{help}\n#{text}"
    end

    # point stdout through less, print, then restore stdout
    less = IO.popen('/usr/bin/less', 'w')
    begin
      less.puts text

    # this catches the quitting of 'less' before all the output
    # is displayed
    rescue Errno::EPIPE => e
      true
    ensure
      less.close
    end
  end

  # Parse a plist into a Ruby data structure.
  # This enhances Plist::parse_xml taking file paths, as well as XML Strings
  # and reading the files regardless of binary/XML format.
  #
  # see JSS::parse_plist
  # TODO - make all calls to this go directly to JSS.parse_plist
  #
  # @param plist[Pathname, String] the plist XML, or the path to a plist file
  #
  # @return [Object] the parsed plist as a ruby hash,array, etc.
  #
  def self.parse_plist(plist)
    JSS.parse_plist plist
  end # parse_plist

  # Reconnect to both the API and DB with a much larger timeout, and
  # using an alternate DB server if one is defined. Should be used
  # by either the D3::Client for lists, or D3::Admin for reports,
  # with appropriate credentials.
  #
  # @param api_user[String] the user for the api connection
  #
  # @param api_pw[String the pw for the api user
  #
  # @param db_user[String] the user for the db connection
  #
  # @param db_pw[String the pw for the db user
  #
  # @return [Hash<String>] the hostnames of the connected JSS & MySQL servers
  #
  def self.connect_for_reports(api_user, api_pw, db_user, db_pw)
    JSS::API.connect user: api_user, pw: api_pw, timeout: REPORT_CONNECTION_TIMEOUT

    if D3::CONFIG.report_db_server
      begin
        JSS::DB_CNX.connect(
          server: D3::CONFIG.report_db_server,
          user: db_user,
          pw: db_pw,
          timeout: REPORT_CONNECTION_TIMEOUT
        )
        return { db: D3::CONFIG.report_db_server, api: JSS::CONFIG.api_server_name }
      rescue Mysql::ServerError::AccessDeniedError
        raise JSS::AuthenticationError, "Authentication error on report_db_server: Credentials must match #{JSS::CONFIG.db_username} on #{JSS::CONFIG.db_server_name}"
      end # begin
    end # if rpt db server

    JSS::DB_CNX.connect user: db_user, pw: db_pw, timeout: REPORT_CONNECTION_TIMEOUT

    { db: JSS::CONFIG.db_server_name, api: JSS::CONFIG.api_server_name }
  end # connect for report

  # Take in a multiline string and remove whitespace as if it was a
  # Ruby 2.3 'squiggly heredoc' e.g.:
  #
  # The indentation of the least-indented line will be removed
  # from each line of the content.
  #
  # This allows us to get the same results in earlier rubies.
  #
  # See https://infinum.co/the-capsized-eight/multiline-strings-ruby-2-3-0-the-squiggly-heredoc
  #
  # @param text[String] The text to squiggilize
  #
  # @return [String] the squiggilized text
  #
  def self.squiggilize_heredoc(text)
    leading_space_re = /^( +)/
    trim_length =
      text.lines.reject { |l| l.chomp.empty? }.map do |l|
        l =~ leading_space_re
        Regexp.last_match(1) ? Regexp.last_match(1).length : 0
      end.min
    trim_sub_re = /^ {#{trim_length}}/
    trimmed_text = ''
    text.each_line { |l| trimmed_text << l.sub(trim_sub_re, '') }
    trimmed_text
  end

end # module
