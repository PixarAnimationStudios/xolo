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

      # See comments for Xolo::Server::Helpers::TitleEditor
      #
      module TitleEditor

        # This is how we 'mix in' modules to Sinatra servers
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
        #
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

        # Routes
        #
        ##############################
        ##############################

        ###############
        get '/title-editor/titles' do
          log_debug "Fetching Title Editor titles for #{session[:admin]}"
          wcnx = ted_cnx
          body Windoo::SoftwareTitle.all(cnx: wcnx).map { |t| t[:id] }.sort
        ensure
          wcnx&.disconnect
        end

      end # Module

    end #  Routes

  end #  Server

end # module Xolo
