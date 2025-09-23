# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#
#

# frozen_string_literal: true

# main module
module Xolo

  module Admin

    # Storage and access to a history of progress-data from
    # long-running Xolo server processes.
    #
    # E.g.. when you run 'xadm delete-title' you'll get a live
    # progress updates of everything happening. That log is stored for
    # a while (3 days) on the server.
    #
    # Later, esp if you used --quiet and didn't see the progress or any
    # errors initially
    # you'll be able to re-view the progress log, if it still exists
    # on the server
    #
    module ProgressHistory

      # Constants
      ##########################
      ##########################

      APP_SUPPORT_DIR = '~/Library/Application Support/xadm/'
      PROGRESS_HISTORY_FILENAME = 'com.pixar.xolo.admin.progress_history.yaml'

      # prog files on the server last 3 days, add an extra to
      # account for timing of daily cleanup on the server.
      # if the file is already gone from the server, we'll tell
      # the user
      PROGRESS_FILE_LIFETIME = 4 * 24 * 3600

      # Module Methods
      ##########################
      ##########################

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # when this module is extended
      def self.extended(extender)
        Xolo.verbose_extend extender, self
      end

      # Instance Methods
      ##########################
      ##########################

      # @return [Pathname] The expanded path tot he  prog. history dir for this user
      ###########################
      def app_support_dir
        return @app_support_dir if @app_support_dir

        @app_support_dir = Pathname.new(APP_SUPPORT_DIR).expand_path
        @app_support_dir.mkpath
        @app_support_dir
      end

      # @return [Pathname] The prog. history file for this user
      ###########################
      def progress_history_file
        @progress_history_file ||= (app_support_dir + PROGRESS_HISTORY_FILENAME)
      end

      # The current history of progress streams for this user
      # keys are Time objects when the entry was created
      # values are sub-hashes with :command, and :url keys
      # the command being the xadm command, e.g. 'delete-version'
      # and the URL being the url to the progress stream file on the server.
      #
      # before returning the hash, any expired entries are removed
      #
      # @return [Hash] the current progress history for this user
      ###################
      def progress_history
        progress_history_file.pix_touch
        history = YAML.load progress_history_file.read
        history ||= {}

        now = Time.now
        history.delete_if { |k, _v| now - k > PROGRESS_FILE_LIFETIME }

        history
      end

      # Add an entry to the progress history
      #
      # @prarm url_path [String] the xolo server path to the progress file.
      #
      # @return [void]
      ######################
      def add_progress_history_entry(url_path)
        history = progress_history
        history[Time.now] = {
          command: cli_cmd.command,
          url_path: url_path
        }

        progress_history_file.pix_atomic_write YAML.dump(history)
      end

    end # module

  end # module Admin

end # module Xolo
