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

    INFO_BANNER = D3.squiggilize_heredoc <<-ENDBANNER
      Display info about titles and versions in d3:

         d3admin info <title> [--version <version>]

      If no version is provided, info about the released version is displayed.

      If no version is released, info about the latest version is displayed.

      Options:
    ENDBANNER

    def parse_info_opts
      Optimist.options do
        banner INFO_BANNER
        opt :version, 'Display info about this version of the title', short: '-v', type: :string
      end
    end

  end # class AdminApp

end # module Xolo
