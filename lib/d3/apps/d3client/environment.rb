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

    ############### Class Constants #################

    #
    # Environment Vars to set during certain processes
    #
    ENV_STATES = {

      # set to 1 during a sync
      sync: 'D3_SYNCING',

      # set to 1 if --force was used
      force: "D3_FORCE",

      # set to the admin name running d3
      admin: "D3_ADMIN",

      # set to 1 if client was set to debug mode.
      debug: "D3_DEBUG",

      # set to 1 if an install is an auto-install
      auto_install: "D3_AUTO_INSTALLING",

      # set to 1 if an install is an auto-update
      auto_update: "D3_AUTO_UPDATING",

      # set to the patch of the rcpt being UNinstalled
      uninstalling_before_install: "D3_UNINSTALLING_BEFORE_INSTALL",

      # set to the patch of the pkg being installed
      pre_install: "D3_RUNNING_PRE_INSTALL",

      # set to the patch of the pkg being installed
      installing: "D3_INSTALLING",

      # set to the status of the pkg being installed
      pkg_status: "D3_PKG_STATUS",

      # set to the patch of the pkg being installed
      post_install: "D3_RUNNING_POST_INSTALL",

      # set to the patch of the pkg being expired
      expiring: "D3_EXPIRING_PKG",

      # set to a space-separated list if patchs expired, if any
      # when the expiration policy is runing
      finished_expirations: "D3_FINISHED_EXPIRATIONS",

      # set to the patch of the pkg being uninstalled
      pre_remove: "D3_RUNNING_PRE_REMOVE",

      # set to the patch of the pkg being uninstalled
      removing: "D3_UNINSTALLING",

      # set to the patch of the pkg being uninstalled
      post_remove: "D3_RUNNING_POST_REMOVE",

      # set to a space-separated list if patchs of items in the puppy-queue
      # when the puppytime notification policy is running
      puppytime_notification: "D3_NOTIFYING_PUPPIES",

      # set to 1 during logout-installation of pkgs requiring reboot
      puppytime: "D3_RUNNING_PUPPYTIME",

      # set to 1 during the puppy-reboot-policy
      # (generally this means a logout is happening and a reboot will happen)
      puppytime_reboot: "D3_REBOOTING_PUPPIES"

    }

    ############### Class Methods #################

    # Set an ENV variable to the 'set' state, usually '1'
    #
    # @param var[Symbol] which var to set, one of the keys of ENV_STATES
    #
    # @param value[#to_s] the value for the var, defaults to '1'
    #
    # @return [void]
    #
    def self.set_env (var, value = 1)
      raise JSS::InvalidDataError, "var must be one of: :#{ENV_STATES.keys.join(' :')}" unless ENV_STATES.keys.include? var
      ENV[ENV_STATES[var]] = value.to_s
    end

    # Unset an ENV variable
    #
    # @param var[Symbol] which var to unset, one of the keys of ENV_STATES
    #
    # @return [void]
    #
    def self.unset_env (var)
      raise JSS::InvalidDataError, "var must be one of: :#{ENV_STATES.keys.join(' :')}" unless ENV_STATES.keys.include? var
      ENV[ENV_STATES[var]] = nil
    end

    # Unset all ENV vars
    #
    # @return [void]
    #
    def self.unset_all_env
      ENV_STATES.keys.each{|v| ENV[ENV_STATES[v]] = nil }
    end
  end # class Client
end # module D3
