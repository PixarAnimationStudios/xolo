# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

# frozen_string_literal: true

# main module
module Xolo

  # Server Module
  module Server

    module Routes

      module Uploads

        # This is how we 'extend' modules to Sinatra servers
        # for route definitions and similar things
        #
        # (things to be 'included' for use in route and view processing
        # are mixed in by delcaring them to be helpers)
        #
        # We make them extentions here with
        #    extend Sinatra::Extension (from sinatra-contrib)
        # and then 'register' them in the server with
        #    register Xolo::Server::<Module>
        # Doing it this way allows us to split the code into a logical
        # file structure, without re-opening the Sinatra::Base server app,
        # and let xeitwork do the requiring of those files
        extend Sinatra::Extension

        # Module methods
        ##############################
        ##############################

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # when this module is extended
        def self.extended(extender)
          Xolo.verbose_extend extender, self
        end

        # This hash contains upload progress stream urls
        # for file uploads, keyed by session[:xolo_id]
        # Individual sessions.
        # Should be accessible from anywhere via
        # Xolo::Server::App.file_upload_progress_files
        # or Xolo::Server::Routes::Uploads.file_upload_progress_files
        #
        # @return [Hash {String => String}]
        ##########################
        def file_upload_progress_files
          @file_upload_progress_files ||= {}
        end

        # Routes
        ##############################
        ##############################

        # # param with the uploaded file must be :file
        # ######################
        # post '/upload/ssvc-icon/:title' do
        #   process_incoming_ssvc_icon
        #   body({ result: :uploaded })
        # end

        # # param with the uploaded file must be :file
        # ######################
        # post '/upload/pkg/:title/:version' do
        #   process_incoming_pkg
        #   body({ result: :uploaded })
        # end

        # param with the uploaded file must be :file
        ######################
        post '/upload/test' do
          with_streaming do
            process_incoming_testfile
          end
        end

      end # Module

    end #  Routes

  end #  Server

end # module Xolo
