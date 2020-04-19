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

module Xolo

  # the admin app
  class AdminApp

    SEARCH_BANNER = Xolo.squiggilize_heredoc <<-ENDBANNER
      Search for d3 for titles or versions matching given text.
      Alternatively search for computer group names used in d3 scoping.

      Search for titles/versions:
        d3admin search <search text> [--pilots]

      Search for computer groups used in d3 scope:
        d3admin search <search text> --groups

      Any title, version, or group name containing the text is listed.

      Options for searching:
    ENDBANNER

    def parse_search_opts
      Optimist.options do
        banner SEARCH_BANNER
        opt :pilots, 'Limit the list to unreleased versions', short: '-p'
        opt :version, 'Display info about this version of the title', short: '-v', type: :string
        opt :groups, 'Search computer groups, not titles & versions', short: '-g'
      end
    end

  end # class AdminApp

end # module Xolo
