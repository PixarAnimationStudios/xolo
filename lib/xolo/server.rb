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

require 'xolo'

# Server Standard Libraries
######
require 'logger'
require 'openssl'
require 'securerandom'
require 'singleton'
require 'json'
require 'yaml'
require 'open3'
require 'base64'

# Gems
######

require 'sinatra/base'
require 'sinatra/custom_logger'
require 'sinatra/extension' # see https://sinatrarb.com/contrib/extension
require 'thin'
require 'ruby-jss'
require 'windoo'
require 'concurrent/hash'
require 'concurrent/atomic/reentrant_read_write_lock'
require 'concurrent/executor/thread_pool_executor'

module Xolo

  # The Xolo Server is the focal point for a Xolo installation.
  # It centralizes and standardizes all communication between
  # the serverside parts of Xolo:
  #
  # - The Xolo Admin command-line application 'xadm'
  #   - Used to manage software deployed by Xolo either manually
  #     or via automated scripts (e.g. Xcode builds)
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
  # The Xolo client tool 'xolo', used on managed Macs, does not communicate
  # directly with the Xolo server. Instead, it communicates with the Jamf Pro, mostly
  # by running 'jamf policy' commands.
  #
  #
  module Server

    # Mixins & extensions
    ##############################
    ##############################

    include Xolo::Server::Constants
    extend Xolo::Server::CommandLine
    extend Xolo::Server::ObjectLocks
    include Xolo::Server::Log

    # Constants
    #############################
    #############################

    # everything xolo-related in Jamf is in this category
    # (this is never used as a SSvc category - that should be set per title)
    JAMF_XOLO_CATEGORY = 'xolo'

    # Module methods
    ##############################
    ##############################

    ################
    def self.start_time
      @start_time
    end

    ################
    def self.start_time=(t)
      @start_time = t
    end

    ################
    def self.app_env
      @app_env
    end

    ################
    def self.app_env=(e)
      ENV['APP_ENV'] = e.to_s
      @app_env = e
    end

    ################
    def self.debug=(bool)
      @debug = bool ? true : false
    end

    ################
    def self.debug?
      @debug
    end

    ################
    def self.config
      Xolo::Server::Configuration.instance
    end

    # threads for reporting
    ##########################
    def self.thread_info
      info = {}
      Thread.list.each do |thr|
        name =
          if thr.name
            thr.name
          elsif Thread.main == thr
            'Main'
          elsif thr.to_s.include? 'eventmachine'
            "eventmachine-#{thr.object_id}"
          else
            thr.to_s
          end
        info[name] = thr.status
      end

      info
    end

  end # Server

end # Xolo
