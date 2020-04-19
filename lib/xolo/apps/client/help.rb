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
  class Client < JSS::Client
    module Help
      extend self

      USAGE = "Usage: d3 action [target [...]] [options]\nUse -H for help"

      # Return the d3amin help text
      #
      # Its far easier and more flexible to maintain the visual layout of
      # this complex help as a single large heredoc, than it is to build it
      # programmatically from the commands and options hashes
      # The downside is that it must be manually updated when those hashes
      # change.
      #
      # @return [String] the d3 help text
      #
      def help_text
        helptxt = <<-ENDHELP

d3: package/patch management & deployment tool to enhance the package-
handling capabilities of Jamf Pro.

#{USAGE}

All actions have a 1-2 character shortcut.

For details see https://github.com/PixarAnimationStudios/depot3/wiki/Client

Actions:
  install   i  <title/patch>       - Install packages or queue for logout
  uninstall u  <title>               - Uninstall packages
  freeze    f  <title>               - Stop auto-updates of this title
  thaw      t  <title>               - Resume auto-updates of this title
  forget    fg <title>               - Remove receipt without uninstalling
  dequeue   dq <title>               - Remove a pending logout install
  sync      s                           - Update receipt data, do auto-installs
                                          update installed software & uninstall
                                          expired receipts
  help                                  - Show this help summary

List Actions:
  list-available  la                    - Live pkgs available to this computer
  list-installed  li                    - Receipts on this computer
  list-manual     lm                    - Manually installed receipts
  list-pilots     lp                    - Pilot receipts on this computer
  list-frozen     lf                    - Frozen receipts on this computer
  list-queue      lq                    - Pending puppy (logout) installs
  list-details    ld <title/patch> - Package & receipt details
  list-files      ls <title/patch> - Files installed by the package
  query-file      qf <path>             - Which packages install <path>?

Options:
  -q, --quiet                  - Be as silent as possible,
                                 use twice for more silence
  -v, --verbose                - Give more detail about what's happening,
                                 use twice for more details
  -p, --puppies                - Do puppy installs now, instead of queuing
                                 When used with 'install', the pkgs
                                 pkgs are installed immediately
                                 When used with 'sync' any queued puppies
                                 are installed immediately
  -f, --force                  - Force d3 to perform unnatural acts
  -a, --admin <admin>          - The name of the admin using d3
  -N, --no-puppy-notification  - Don't run the puppy-notification policy
  -e, --expiration <days>      - With 'install', set a custom expiration
                                 if the pkg is expirable
  -F, --freeze                 - With 'install', freeze receipt immediately
  -d, --debug                  - Set verbosity and logging to full blast
  -V, --version                - Show d3 version info
  -H, --help                   - Show this help info


Notes
 - All <targets> can be a list of several, space-separated
 - When a title is given as a target for install, list-details, or
   list-files, the currently live patch is used.

ENDHELP
        helptxt
      end # help_text

    end # module help
  end # class
end # module Xolo
