### Copyright 2022 Pixar
###
###    Licensed under the Apache License, Version 2.0 (the "Apache License")
###    with the following modification; you may not use this file except in
###    compliance with the Apache License and the following modification to it:
###    Section 6. Trademarks. is deleted and replaced with:
###
###    6. Trademarks. This License does not grant permission to use the trade
###       names, trademarks, service marks, or product names of the Licensor
###       and its affiliates, except as required to comply with Section 4(c) of
###       the License and to reproduce the content of the NOTICE file.
###
###    You may obtain a copy of the Apache License at
###
###        http://www.apache.org/licenses/LICENSE-2.0
###
###    Unless required by applicable law or agreed to in writing, software
###    distributed under the Apache License with the above modification is
###    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
###    KIND, either express or implied. See the Apache License for the specific
###    language governing permissions and limitations under the Apache License.
###
###

# frozen_string_literal: true

# frozen_string_literal: true

module Xolo

  module TitleEditor

    class Connection

      # This module defines constants related to API connctions, used throughout
      # the connection class and elsewhere.
      ##########################################
      module Constants

        # A string indicating we are not connected
        NOT_CONNECTED = 'Not Connected'

        # if @name is any of these when a connection is made, it
        # is reset to a default based on the connection params
        NON_NAMES = [NOT_CONNECTED, :unknown, nil, :disconnected].freeze

        HTTPS_SCHEME = 'https'

        # The Jamf default SSL port for on-prem servers
        ON_PREM_SSL_PORT = 8443

        # The https default SSL port for Jamf Cloud servers
        HTTPS_SSL_PORT = 443

        # Recognize Jamf Cloud servers
        JAMFCLOUD_DOMAIN = 'jamfcloud.com'

        # JamfCloud connections default to 443, not 8443
        JAMFCLOUD_PORT = HTTPS_SSL_PORT

        # The top line of an XML doc for submitting data via Classic API
        XML_HEADER = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>'

        DFT_OPEN_TIMEOUT = 60
        DFT_TIMEOUT = 60

        # The Default SSL Version
        DFT_SSL_VERSION = 'TLSv1_2'

        RSRC_NOT_FOUND_MSG = 'The requested resource was not found'

        # values for the 'format' param of #c_get
        GET_FORMATS = %i[json xml].freeze

        HTTP_ACCEPT_HEADER = 'Accept'
        HTTP_CONTENT_TYPE_HEADER = 'Content-Type'

        MIME_JSON = 'application/json'
        MIME_XML = 'application/xml'

        # Only these variables are displayed with PrettyPrint
        # This avoids, especially, the caches, which are available
        # as attr_readers
        PP_VARS = %i[
          @name
          @connected
          @open_timeout
          @timeout
          @server_path
          @connect_time
        ].freeze

        SET_COOKIE_HEADER = 'set-cookie'

        COOKIE_HEADER = 'Cookie'

        STICKY_SESSION_COOKIE_NAME = 'APBALANCEID'

      end # module

    end # class

  end

end # module Jamf
