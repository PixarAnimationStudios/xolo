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

  #####################################
  # Module Constants
  ####################################

  # where do we keep our stuff?
  SUPPORT_DIR = Pathname.new "/Library/Application Support/d3"


  # the default name to use as the @@script_admin
  DFT_CLI_ADMIN = "unknown"

  # Shouldn't see this ever, but if there's no admin name
  # for a pkg in the puppy queue, use this
  DFT_PUPPY_ADMIN = "unknown-puppyq"

  # the 'admin' name when a pkg is auto-installed
  # during a d3 sync
  AUTO_INSTALL_ADMIN = "auto-installed"

  # When this word is used as an auto_group name
  # it means that all clients should get the package
  # automatically.
  STANDARD_AUTO_GROUP = "standard"

  # When a real admin name is needed, it cant be one of these,
  # or those listed in Xolo::CONFIG.client_prohibited_admin_names
  # or we'll raise an exception
  DISALLOWED_ADMINS = [nil, "", "root", DFT_CLI_ADMIN, AUTO_INSTALL_ADMIN]

  # reports can take a long time to generate, lets set the timeout to a long time.
  REPORT_CONNECTION_TIMEOUT = 3600

  # when this file exists, d3, d3admin are set to debug mode. This is
  # useful when you have a d3 command embedded in some other tool, but need to get
  # debug logging.
  DEBUG_FILE = Pathname.new "/tmp/d3debug-on"

end # module
