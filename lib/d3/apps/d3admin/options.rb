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

module D3

  # CLI Option handling for the d3admin CLI app
  #
  class AdminApp

    attr_reader :global_opts

    attr_reader :action

    attr_reader :action_opts

    attr_reader :target

    OPTS_FILE_DIR = Pathname.new 'd3/apps/d3admin/options'

    ADD_TITLE_ACTION = 'add-title'.freeze
    EDIT_TITLE_ACTION = 'edit-title'.freeze
    DELETE_TITLE_ACTION = 'delete-title'.freeze
    ADD_EA_ACTION = 'add-ea'.freeze
    DELETE_EA_ACTION = 'delete-ea'.freeze
    ADD_VERSION_ACTION = 'add-version'.freeze
    EDIT_VERSION_ACTION = 'edit-version'.freeze
    DELETE_VERSION_ACTION = 'delete-version'.freeze
    RELEASE_ACTION = 'release'.freeze
    INFO_ACTION = 'info'.freeze
    SEARCH_ACTION = 'search'.freeze
    REPORT_ACTION = 'report'.freeze
    CONFIG_ACTION = 'config'.freeze

    ACTIONS = {
      ADD_TITLE_ACTION => {
        aliases: %w[at],
        opts_file: 'title_opts',
        parse_method: :parse_title_opts,
        run_method: :add_title
      },
      EDIT_TITLE_ACTION => {
        aliases: %w[et],
        opts_file: 'title_opts',
        parse_method: :parse_title_opts,
        run_method: :edit_title
      },
      DELETE_TITLE_ACTION => {
        aliases: %w[dt],
        opts_file: 'title_opts',
        parse_method: :parse_title_opts,
        run_method: :delete_title
      },

      ADD_EA_ACTION => {
        aliases: %w[ea],
        opts_file: 'title_opts',
        parse_method: :parse_title_opts,
        run_method: :add_ea
      },
      DELETE_EA_ACTION => {
        aliases: %w[dea],
        opts_file: 'title_opts',
        parse_method: :parse_title_opts,
        run_method: :delete_ea
      },

      ADD_VERSION_ACTION => {
        aliases: %w[av],
        opts_file: 'version_opts',
        parse_method: :parse_version_opts,
        run_method: :add_version
      },
      EDIT_VERSION_ACTION => {
        aliases: %w[ev],
        opts_file: 'version_opts',
        parse_method: :parse_version_opts,
        run_method: :edit_version
      },
      DELETE_VERSION_ACTION => {
        aliases: %w[dv],
        opts_file: 'version_opts',
        parse_method: :parse_version_opts,
        run_method: :delete_version
      },
      RELEASE_ACTION => {
        aliases: %w[rel],
        opts_file: 'version_opts',
        parse_method: :parse_version_opts,
        run_method: :release
      },
      INFO_ACTION => {
        aliases: %w[i],
        opts_file: 'info_opts',
        parse_method: :parse_info_opts,
        run_method: :show_info
      },
      SEARCH_ACTION => {
        aliases: %w[s],
        opts_file: 'search_opts',
        parse_method: :parse_search_opts,
        run_method: :search
      },
      REPORT_ACTION => {
        aliases: %w[rpt],
        opts_file: 'report_opts',
        parse_method: :parse_report_opts,
        run_method: :show_report
      },
      CONFIG_ACTION => {
        aliases: %w[c],
        opts_file: 'config_opts',
        parse_method: :parse_config_opts,
        run_method: :configure
      }
    }.freeze

    # Parse the commandline opts. The action must come before the target.
    def parse_cli_opts
      @global_opts = OpenStruct.new parse_global_opts
      @action = parse_action
      @action_opts = OpenStruct.new parse_action_opts
      @target = ARGV.shift
    end # parse cli opts

    def parse_action
      cli_action = ARGV.shift
      return cli_action if ACTIONS.key? cli_action

      ACTIONS.each do |act, details|
        return act if details[:aliases].include? cli_action
      end # each do act

      Optimist.die "Unknown action: '#{cli_action}'\n#{USAGE}"
    end

    # ensure the full action string is in @action, and use Optimist to
    # parse the action opts for that action into a hash
    def parse_action_opts
      action_details = ACTIONS[@action]
      opts_file = OPTS_FILE_DIR + action_details[:opts_file]
      require opts_file.to_s
      send action_details[:parse_method]
    end # parse_action_opts

  end # class AdminApp

end # module d3

require 'd3/apps/d3admin/options/global_opts'
