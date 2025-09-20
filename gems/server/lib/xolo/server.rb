# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

# frozen_string_literal: true

# This file is the entry point for loading the Xolo Server
#
# You can and should require the convenience file 'xolo-server.rb'
#
#    require 'xolo-server'

require 'xolo/core'

# Standard Libraries
######
require 'logger'
require 'openssl'
require 'securerandom'
require 'singleton'
require 'json'
require 'yaml'
require 'open3'
require 'base64'
require 'resolv'
require 'shellwords'
require 'net/smtp'

# Gems
######

require 'ruby-jss'
require 'windoo'
require 'sinatra/base'
require 'sinatra/custom_logger'
require 'sinatra/extension' # see https://sinatrarb.com/contrib/extension
require 'thin'
require 'concurrent/hash'
require 'concurrent/atomic/reentrant_read_write_lock'
require 'concurrent/executor/thread_pool_executor'
require 'concurrent/timer_task'

# Xolo Server
######
require 'xolo/server/constants'
require 'xolo/server/configuration'
require 'xolo/server/command_line'
require 'xolo/server/log'
require 'xolo/server/object_locks'
require 'xolo/server/title'
require 'xolo/server/version'

require 'xolo/server/mixins/changelog'
require 'xolo/server/mixins/title_jamf_access'
require 'xolo/server/mixins/title_ted_access'
require 'xolo/server/mixins/version_jamf_access'
require 'xolo/server/mixins/version_ted_access'

require 'xolo/server/helpers/log'
require 'xolo/server/helpers/auth'
require 'xolo/server/helpers/notification'
require 'xolo/server/helpers/pkg_signing'
require 'xolo/server/helpers/progress_streaming'
require 'xolo/server/helpers/title_editor'
require 'xolo/server/helpers/jamf_pro'
require 'xolo/server/helpers/titles'
require 'xolo/server/helpers/versions'
require 'xolo/server/helpers/client_data'
require 'xolo/server/helpers/file_transfers'
require 'xolo/server/helpers/maintenance'

require 'xolo/server/app'

require 'xolo/server/routes'
require 'xolo/server/routes/auth'
require 'xolo/server/routes/jamf_pro'
require 'xolo/server/routes/maint'
require 'xolo/server/routes/title_editor'
require 'xolo/server/routes/titles'
require 'xolo/server/routes/uploads'
require 'xolo/server/routes/versions'

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
  # The Xolo server also (eventually) implements a webhook handling server that specifically
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

    ################
    def self.shutting_down?
      @shutting_down
    end

    ################
    def self.shutting_down=(bool)
      @shutting_down = bool ? true : false
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
