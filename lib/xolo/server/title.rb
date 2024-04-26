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
#

# frozen_string_literal: true

# main module
module Xolo

  module Server

    # A title in Xolo, as used on the server
    class Title < Xolo::Core::BaseClasses::Title

      # Mixins
      #############################
      #############################

      # Constants
      ######################
      ######################

      # On the server, xolo titles are represented by directories
      # in this directory, named with the title name.
      #
      # So a title 'foobar' would have a directory
      #    (Xolo::Server::DATA_DIR)/titles/foobar/
      # and in there will be a file
      #    foobar.json
      # with the data for the Title instance itself
      #
      # Also in there will be a 'versions' dir containing json
      # files for each version of the title.
      # See {Xolo::Server::Version}
      #
      TITLES_DIR = Xolo::Server::DATA_DIR + 'titles'

      # Class Methods
      ######################
      ######################

      # A list of all known title dirs
      # @return [Array<Pathname>]
      ######################
      def self.title_dirs
        TITLES_DIR.children
      end

      # A list of all known titles
      # @return [Array<String>]
      ######################
      def self.all_titles
        title_dirs.map(&:basename).map(&:to_s)
      end

      # The title dir for a given title on the server
      # @pararm title [String] the title we care about
      # @return [Pathname]
      #####################
      def self.title_dir(title)
        TITLES_DIR + title
      end

      # The title data file for a given title
      # @pararm title [String] the title we care about
      # @return [Pathname]
      #####################
      def self.title_data_file(title)
        title_dir(title) + "#{title}.json"
      end

      # @return [Xolo::Server::Title] load an existing title
      #   from the on-disk JSON file
      ######################
      def self.load(title)
        new parse_json(title_data_file(title).read)
      end

      # Attributes
      ######################
      ######################

      # Constructor
      ######################
      ######################

      # Instance Methods
      ######################
      ######################

      # The title dir for this title on the server
      # @return [Pathname]
      #########################
      def title_dir
        self.class.title_dir title
      end

      # The title data file for this title on the server
      # @return [Pathname]
      #########################
      def title_data_file
        self.class.title_data_file title
      end

      # Save a new title, adding or updating to the
      # local filesystem, Jamf Pro, and the Title Editor as needed
      #
      # @return [void]
      #########################
      def save
        save_to_file
        # TODO: save or update in Jamf and the Title Editor
      end

      # Save our current data out to our data file
      # This overwrites the existing data.
      #
      # @return [void]
      ##########################
      def save_to_file
        title_dir.mkpath
        title_data_file.pix_atomic_write to_json
      end

      # Delete the title and all of its version
      # @return [void]
      ##########################
      def delete
        # TODO: delete from Jamf and the Title Editor

        title_dir.rmtree
      end

    end # class Title

  end # module Admin

end # module Xolo
