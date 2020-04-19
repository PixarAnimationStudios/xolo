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

  # the admin app
  class AdminApp

    USAGE = 'Usage: d3admin [global opts] <action> <target> [action opts]'.freeze

    GLOBAL_BANNER = D3.squiggilize_heredoc <<-ENDBANNER
      d3admin is a command-line tool for administering software in d3, a
      package/patch management & deployment tool that enhances the capabilities
      of Jamf Pro.

      #{USAGE}

      Available actions and their targets:

        add-title <title>                Add a new title with given settings
        edit-title <title>               Modify title settings
        delete-title <title>             Delete a title and all of its versions
        add-ea <title> -E <path>         Add an ext. attr. script to a title
        delete-ea <title> -E <name>      Delete an ext. attr. from a title.
        add-version <title> -v <vers>    Add a new version to a title
        edit-version <title> -v <vers>   Modify version settings
        delete-version <title> -v <vers> Delete a version
        release <title> -v <vers>        Release a version
        info <title> [-v <vers>]         Show details of a title or version
        search <title/group>             List matching titles or group scoping
        report <title/computer>          Report about titles on computers
        config <setting/display>         Set/show local d3admin configuration

      To see the help & options for each action, use:
         d3admin <action> --help

      For detailed documentation see: (TODO: Update this URL)
         https://github.com/PixarAnimationStudios/depot3/wiki/Admin

      Global options:
    ENDBANNER

    def parse_global_opts
      Optimist.options do
        banner GLOBAL_BANNER
        opt :auto_confirm, "Don't ask for confirmation before acting, BE CAREFUL!", short: '-A'
        opt :debug, 'Show debug info and ruby backtraces', short: :none
        opt :ext, 'With --help/-h, show extended help text', short: :none
        stop_on ACTIONS.keys
      end
    end # parse_global_opts

  end # class AdminApp

end # module D3
