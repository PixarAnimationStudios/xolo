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

  # is the module fully loaded?
  #
  # @return [Boolean]
  #
  def self.loaded?
    @loaded
  end


  # The current verbosity level
  # @return [Integer]
  #
  def self.verbosity
    @verbosity ||= Xolo::Log::DFT_VERBOSITY
  end

  # Set the level of verbosity to stderr.
  # Messages logged via D3#log, of this severity and higher,
  # will show up on stderr
  # They *may* show up in the log depending on the Xolo::LOG.level
  #
  # @param new_verbosity[Symbol, Integer] the new value, one of Xolo::Log::LOG_LEVELS
  #
  # @return [void]
  #
  def self.verbosity= (new_val)
    # range is 0-4 if we're given an integer
    # so force it to be in the range.
    if new_val.is_a? Fixnum
      new_val = 0 if new_val < 0
      new_val = 4 if new_val > 4
    end
    @verbosity = Xolo::Log.check_level(new_val)
  end


  # Have we been asked to be forceful, and perform
  # unnatural acts?
  # Force is used in many different was in many places
  # so we'll store it here and anything can access it
  # using Xolo::force, Xolo::unforce, and Xolo::forced?
  @@force = false

  # Turn on force, module-wide
  #
  # @return [void]
  #
  def self.force
    @@force = true
    Xolo::Client.set_env :force
  end

  # Turn off force, module-wide
  #
  # @return [void]
  #
  def self.unforce
    @@force = false
    Xolo::Client.unset_env :force
  end

  # Is force turned on, module-wide?
  #
  # @return [Boolean]
  #
  def self.forced?
    @@force
  end

  # Are we connected to the API and DB servers?
  #
  # returns false if the are not both connected
  # returns a hash like this if both are connected:
  #
  # {:api => "user@api_server", :db => "sql_user@db_server"}
  #
  # @return [false, Hash] Are we connected to the servers, and if so,
  #   what hosts and usernames
  #
  def self.connected?
    return false unless loaded?
    return false unless JSS::API.connected? and JSS::DB_CNX.connected?
    return {
      :api => (JSS::API.cnx.options[:user] + "@" + JSS::API.cnx.options[:server]),
      :db => (JSS::DB_CNX.user + "@" + JSS::DB_CNX.server)
    }
  end

end # module
