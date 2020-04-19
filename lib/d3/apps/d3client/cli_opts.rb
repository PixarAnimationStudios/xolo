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
  class Client < JSS::Client

      # NOTE: In Ruby 2.0 and up, Hashes are ordered in the order their
      # elements are defined or added to the hash.
      # So, the order here will affect the help output.

      ACTIONS = {
        install: {
          :aka => :i,
          :help => "install the currently live version of the given title(s)",
          :needs_admin => true,
          :arg => :"title or patch",
          :needs_connection => true
        },
        uninstall: {
          :aka => :u,
          :help => "uninstall the given title(s)",
          :arg => :title,
          :needs_connection => true
        },
        dequeue: {
          :aka => :dq,
          :help => "remove a pending puppytime (logout) pkg. Use 'all' to clear the queue",
          :arg => :title
        },
        sync: {
          :aka => :s,
          :help => "update installed pkgs, install new auto-installed ones",
          :needs_connection => true
        },
        freeze: {
          :aka => :f,
          :help => "stop auto-updates of this title during sync",
          :needs_connection => false,
          :arg => :title
        },
        thaw: {
          :aka => :t,
          :help => "resume auto-updates of this title during sync",
          :needs_connection => false,
          :arg => :title
        },
        forget: {
          :aka => :fg,
          :help => "Remove receipt but don't try uninstalling.",
          :needs_connection => false,
          :arg => :title
        },
        list_available: {
          :aka => :la,
          :help => "list all available live installers on the server",
          :needs_connection => true
        },
        list_installed: {
          :aka => :li,
          :help => "list all installed d3 pkgs on this machine",
          :needs_root => false
        },
        list_manual: {
          :aka => :lm,
          :help => "list all d3 pkgs on this machine not auto-installed",
          :needs_root => false
        },
        list_pilots: {
          :aka => :lp,
          :help => "list pkgs currently in pilot on this machine",
          :needs_root => false
        },
        list_frozen: {
          :aka => :lf,
          :help => "list pkgs currently frozen on this machine",
          :needs_root => false
        },
        list_puppies: {
          :aka => :lq,
          :help => "list any queued pkgs awaiting puppytime at logout",
          :needs_root => false
        },
        list_queue: {
          :aka => :lq,
          :help => "list any queued pkgs awaiting puppytime at logout",
          :needs_root => false
        },
        list_details: {
          :aka => :ld,
          :help => "show detailed info about packages in d3",
          :arg =>  :"title or patch",
          :needs_connection => true
        },
        list_files: {
          :aka => :ls,
          :help => "list the files installed by the given patchs",
          :arg => :"title or patch" ,
          :needs_connection => true
        },
        query_file: {
         :aka => :qf,
         :help => "list any pkgs that install the given path(s)",
         :arg => :path,
         :needs_connection => true
        },
        help: {
         :aka => :h,
         :help => "show this help text",
         :needs_root => false
        },
        version: {
         :aka => :v,
         :help => "show the current versions of d3, and its libraries",
         :needs_root => false
        }
      }  # end COMMANDS

      OPTIONS = {

        help: {
          :cli => ['--help','-H', "-h", GetoptLong::NO_ARGUMENT ],
          :help => "show this help text"
        },

        version: {
          :cli => ['--version', '-V', GetoptLong::NO_ARGUMENT ],
          :help => "show the version of d3"
        },

        quiet: {
          :cli => ['--quiet','-q', GetoptLong::NO_ARGUMENT ],
          :help => "spew less to stdout. Use up to 3 times to suppress more output."
        },

        verbose: {
          :cli => ['--verbose','-v', GetoptLong::NO_ARGUMENT ],
          :help => "give more detail to stdout"
        },

        puppies: {
          :cli => ['--puppies', '-p', GetoptLong::NO_ARGUMENT ],
          :help => "do puppy installs immediately, instead of queuing"
        },

        force: {
          :cli => ['--force', '-f', GetoptLong::NO_ARGUMENT ],
          :help => "force d3 to perform unnatural acts"
        },

        freeze: {
          :cli => ['--freeze', '-F', GetoptLong::NO_ARGUMENT ],
          :help => "with 'install', freeze receipt immediately"
        },

        admin: {
          :cli => ['--admin', '-a', GetoptLong::REQUIRED_ARGUMENT ],
          :arg => 'admin',
          :help => "who is doing something with d3?"
        },

        no_logout_notice: {
          :cli => ['--no-puppy-notification', '-N', GetoptLong::NO_ARGUMENT ],
          :help => "don't ask the user to log out for puppies"
        },

        expiration: {
          :cli => ['--expiration', '-e', GetoptLong::REQUIRED_ARGUMENT ],
          :arg => "days",
          :help => "set a custom expiration period to the installed pkgs."
        },

        debug: {
          :cli => ['--debug', '-d', GetoptLong::NO_ARGUMENT ],
          :help => "be as verbose as possible to both std and the log."
        }
      } # end OPTIONS



  end # module client
end # module D3
