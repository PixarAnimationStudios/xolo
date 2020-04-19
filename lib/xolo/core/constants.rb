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

# the main module
module Xolo

  # Core Modules Constants, used by the server and clients
  ####################################

  # File-related constants

  DOT_YML = '.yml'.freeze
  DOT_PKG = '.pkg'.freeze
  PKGUTIL = Pathname.new '/usr/sbin/pkgutil'

  # API constants

  SESSION_KEY = 'd3.session'.freeze

  API_OK_STATUS = 'OK'.freeze
  API_ERROR_STATUS = 'ERROR'.freeze
  API_RESPONSE_STATUSES = [API_OK_STATUS, API_ERROR_STATUS].freeze

  API_LOGGED_IN_MSG = 'logged in'.freeze
  API_NOT_LOGGED_IN_MSG = 'not logged in'.freeze
  API_LOGGED_OUT_MSG = 'logged out'.freeze
  API_CREATED_MSG = 'created'.freeze
  API_UPDATED_MSG = 'updated'.freeze
  API_DELETED_MSG = 'deleted'.freeze

  # Package constants

  # which attributes of a JSS::Package are used by d3?
  # These are fetched by id, so we dn't need to include it
  PACKAGE_ATTRIBUTES = %i[
    name
    allow_uninstalled
    reboot_required
    info
    notes
    os_requirements
    send_notification
  ].freeze

end # module
