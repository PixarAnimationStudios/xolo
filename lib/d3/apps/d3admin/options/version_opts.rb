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

  # To find the id of an existing icon:
  #   - go to any self-service page in the Jamf UI
  #   - Edit
  #   - Click the 'select existing icon' button in the icon section
  #   - right-click/ctrl-click on the icon you want
  #   - Copy Image Location/Link/Address
  #   - Click Cancel to exit icon select, and then click cancel agin to exit editing
  #   - Paste somewhere and you'll see a URL like this  https://myjamfpro.myplace.org/icon?id=21936
  #   - the icon ID is at the end
  #
  # pol = JSS::Policy.fetch 'chrisltest-pol'
  # pol.icon = '/Users/chrisl/Desktop/teddy_cool-512.png'
  #  # ^^ Uploads and takes effect immediately
  #
  # pol.icon = 21936
  #  # ^^ requres pol.save
  # pol.save

  # the admin app
  class AdminApp

    REQUIRED_VERSION_OPTS = %i[
      version
      package
    ].freeze

    VERSION_BANNER = D3.squiggilize_heredoc <<-ENDBANNER
      Working with versions in d3:

      Add a new version:
        d3admin [global opts] add-version <title> --version <version> [version opts]

      Edit a version:
        d3admin [global opts] edit-version <title> --version <version> [version opts]

      Release a version:
        d3admin [global opts] release <title> --version <version>

      Delete a version:
        d3admin [global opts] delete-version <title> --version <version>

      When adding, <version> must not already exist in the <title>.

      A .pkg installer must be associated with the version via --package.
      The value can either be the name of an existing Jamf Package, or a
      path to a locally readable .pkg file.
      Anything containing a '/' is considered a path.
      If your d3 server requires it, the .pkg must be validly signed.

      The following options can be given multiple times:
        --killapp

      NOTE: Pre- and post- install scripts must be embedded in the .pkg

      Options for versions:
    ENDBANNER

    def parse_version_opts
      opts =
        Optimist.options do
          banner VERSION_BANNER

          opt :version, 'Version of the thing installed, required', short: '-v', type: :string
          opt :no_inherit, "Don't inherit values from previous version", short: '-I'
          opt :min_os, 'The minimum OS version this can be installed on', short: '-o', type: :string
          opt :max_os, 'The minimum OS version this can be installed on', short: '-O', type: :string
          opt :removable, 'Can this version be uninstalled?', short: '-u'
          opt :pre_remove, 'Name, or path to pre-remove script', short: '-s', type: :string
          opt :post_remove, 'Name, or path to post-remove script', short: '-S', type: :string
          opt :killapp, "'AppName::BundleId' to kill before install", short: '-x', type: :string, multi: true
          opt :reboot, 'Reboot required after install. Puppies!', short: '-R'
          opt :package, 'A Jamf Pro package name, or path to a local .pkg', short: '-p', tyoe: :string
          opt :keep_pkg, 'Do not remove the package from Jamf Pro when deleting', short: '-k'
        end

      opts
    end # parse_add_opts

  end # class Admin

end # module D3
