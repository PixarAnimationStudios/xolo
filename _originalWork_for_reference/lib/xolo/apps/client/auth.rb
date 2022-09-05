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

  class Client < JSS::Client


    ############### Class Methods #################

    # Connect to the JSS and the DB with read-only connections
    # The connection details must be stored in the D3 and JSS
    # CONFIG data.
    #
    def self.connect
      jss_ro_user = Xolo::CONFIG.client_jss_ro_user
      jss_ro_user ||= JSS::CONFIG.api_username

      db_ro_user = Xolo::CONFIG.client_db_ro_user
      db_ro_user ||= JSS::CONFIG.db_username

      JSS::DB_CNX.connect :server => JSS::CONFIG.db_server_name, :user => db_ro_user, :pw => Xolo::Client.get_ro_pass(:db)
      JSS::API.connect :server => JSS::CONFIG.api_server_name, :user => jss_ro_user, :pw => Xolo::Client.get_ro_pass(:jss)

      Xolo::Database.check_schema_version
    end # connect

    # Disconnect from the JSS and DB
    def self.disconnect
      JSS::API.disconnect if JSS::API.connected?
        JSS::DB_CNX.disconnect if JSS::DB_CNX.connected?
    end # disconnect


    # Get a stored read-only password from a file or
    # an executable.
    #
    # Raises a JSS::UnsupportedError if the file isn't
    # owned by root with 0600 permissions.
    #
    # NOTE: for slightly better security, don't store the
    # result in a variable, use this method as needed to retrieve
    # the passwd every time you need it.
    #
    # See also Xolo::Configuration
    #
    # @param pw[Symbol] which pw to get, one of :jss, :db, :dist, :http
    #
    # @return [String, nil] the password, or nil if the file
    #   isn't defiend, or doesn't exist.
    #
    def self.get_ro_pass (pw)
      raise JSS::InvalidDataError, "Arg must be one of :jss, :db, :dist, :http" unless [:jss, :db, :dist, :http].include? pw

      path = case pw
      when :jss then  Xolo::CONFIG.client_jss_ropw_path
      when :db then Xolo::CONFIG.client_db_ropw_path
      when :dist then Xolo::CONFIG.client_distpoint_ropw_path
      when :http then Xolo::CONFIG.client_http_ropw_path
      end # path = case

      return nil unless path

      # if the path ends with a pipe, its a command that will
      # return the desired password, so remove the pipe,
      # execute it, and return stdout from it.
      if path.end_with? "|"
        cmd = path.chomp '|'
        output = `#{cmd} 2>&1`.chomp
        return output if $CHILD_STATUS.exitstatus.zero?
        raise Xolo::PermissionError, "can't get client password for #{pw}: #{output}"
      end

      file = Pathname.new path
      return nil unless file.file?
      stat = file.stat
      unless ("%o" % stat.mode).end_with? "0600" and stat.uid == 0
        raise JSS::UnsupportedError, "Password file for '#{pw}' has insecure permissions, must be 0600."
      end

      # chomping an empty string removes all trailing \n's and \r\n's
      file.read.chomp('')
    end

    # Actions requiring an admin name

  end # class Client
end # module Xolo
