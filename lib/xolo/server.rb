# Copyright 2023 Pixar
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

# frozen_string_literal: true

# This file is the entry point for loading the Xolo Server.
#
# Do not require this file directly unless you've already done:
#
#    require 'xolo'
#
# because the top-level xolo.rb file must set up autoloading and
# load the Core module first.
#
# You can and should require the convenience file 'xolo-server.rb'
# to load things in the correct order:
#
#    require 'xolo-server'

# Server Standard Libraries
######

# Gems
######

require 'windu'

# Define the module for Zeitwerk
module Xolo

  # The Xolo Server is the focal point for a Xolo installation.
  # It centralizes and standardizes all communication between
  # the parts of Xolo:
  #
  # - The Xolo Admin command-line application
  #   - Used to manage software deployed by xolo either manually
  #     or via automated scripts
  #
  # - A Jamf Title Editor server
  #   - Used as the 'external patch source' hosting locally-developed
  #     software, and/or titles from other sources
  #
  # - A Jamf Pro server
  #   - Connected to the Title Editor, the Jamf internal patch source,
  #     and perhaps other external patch sources.
  #   - Handles initial installation and patching of software on the
  #     managed client Macs via Policies and Patch Policies.
  #
  # The Xolo server also implements a webhook handling server that specifically
  # handles PatchSoftwareTitleUpdated events from the Jamf Pro server. This allows
  # for the automatic packaging, piloting, and maintenance of titles using
  # tools such as AutoPkg.
  #
  #
  module Server

    include Xolo::Server::Constants
    extend Xolo::Server::CommandLine
    include Xolo::Server::Logging
    include Xolo::Server::JamfPro
    include Xolo::Server::TitleEditor

    def self.executable=(path)
      @executable = Pathname.new path
    end

    def self.executable
      @executable
    end

    # the single instance of our configuration object
    def self.config
      Xolo::Server::Configuration.instance
    end

  end # Server

end # Xolo
