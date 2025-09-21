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

      module JamfPro

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

        # We probably don't need this - just for testing for now.
        ###############
        get '/jamf/package-names' do
          log_debug "Jamf: Fetching Jamf Package Names for #{session[:admin]}"
          jamf_cnx
          body Jamf::JPackage.all_names(cnx: jamf_cnx).sort
        ensure
          jamf_cnx&.disconnect
        end

        # A list of all current computer groups, excluding those starting with xolo-
        ###############
        get '/jamf/computer-group-names' do
          log_debug "Jamf: Fetching Jamf ComputerGroup Names for #{session[:admin]}"
          body Jamf::ComputerGroup.all_names(cnx: jamf_cnx).reject { |g|
                 g.start_with? Xolo::Server::JAMF_OBJECT_NAME_PFX
               }.sort
        ensure
          jamf_cnx&.disconnect
        end

        # A list of all current categories
        ###############
        get '/jamf/category-names' do
          log_debug "Jamf: Fetching Jamf Category Names for #{session[:admin]}"
          jcnx = jamf_cnx
          body Jamf::Category.all_names(cnx: jcnx).sort
        ensure
          jcnx&.disconnect
        end

      end # Module

    end #  Routes

  end #  Server

end # module Xolo
