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
#

# frozen_string_literal: true

# main module
module Xolo

  module Admin

    # Methods that process the xadm commands and their options
    #
    module Processing

      # Constants
      ##########################
      ##########################

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

      # Which opts to process, those from walkthru, or from the CLI?
      #
      # @return [OpenStruct] the opts to process
      #######################
      def opts_to_process
        @opts_to_process ||= walkthru? ? walkthru_cmd_opts : cli_cmd_opts
      end

      # update the adm config file using the values from 'xadm config'
      #
      # @return [void]
      ###############################
      def update_config
        Xolo::Admin::Configuration::KEYS.each_key do |key|
          config.send "#{key}=", opts_to_process[key]
        end

        config.save_to_file
      end

      # List all titles in Xolo
      #
      # @return [void]
      ###############################
      def list_titles
        puts '# All titles in Xolo:'
        puts '#####################'
        Xolo::Admin::Title.all_titles(server_cnx).each { |t| puts t }
      end

      # Add a title to Xolo
      #
      # @return [void]
      ###############################
      def add_title
        opts_to_process.title = cli_cmd.title
        new_title = Xolo::Admin::Title.new opts_to_process
        new_title.add server_cnx

        # Upload the version script, if any?

        puts "Title '#{cli_cmd.title}' has been added to Xolo.\nAdd at least one version to enable piloting and deployment"
      rescue StandardError => e
        handle_server_error e
      end

      # Edit/Update a title in Xolo
      #
      # @return [void]
      ###############################
      def edit_title
        opts_to_process.title = cli_cmd.title
        title = Xolo::Admin::Title.new opts_to_process

        title.update server_cnx

        puts "Title '#{cli_cmd.title}' has been updated in Xolo."
      rescue StandardError => e
        handle_server_error e
      end

      # Delete a title in Xolo
      #
      # @return [void]
      ###############################
      def delete_title
        Xolo::Admin::Title.delete cli_cmd.title, server_cnx

        puts "Title '#{cli_cmd.title}' has been deleted from Xolo."
      rescue StandardError => e
        handle_server_error e
      end

      # Show details about a title or version in xolo
      #
      # @return [void]
      ###############################
      def show_info
        cli_cmd.version ? show_version_info : show_title_info
      end

      # Show details about a title in xolo
      #
      # @return [void]
      ###############################
      def show_title_info
        puts "# Info for Title '#{cli_cmd.title}'"
        puts '###################################'

        title = Xolo::Admin::Title.fetch cli_cmd.title, server_cnx
        Xolo::Admin::Title::ATTRIBUTES.each do |attr, deets|
          puts "#{deets[:label]}: #{title.send attr}"
        end
      end

      # Show details about a title in xolo
      #
      # @return [void]
      ###############################
      def show_version_info
        title = cli_cmd.title
        version = cli_cmd.version
      end

    end # module processing

  end # module Admin

end # module Xolo
