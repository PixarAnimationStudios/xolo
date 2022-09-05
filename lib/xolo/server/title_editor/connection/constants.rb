# Copyright 2022 Pixar
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

# frozen_string_literal: true

module Xolo

  module Server 

    module TitleEditor

      class Connection

        # When using included modules to define constants, 
        # the constants have to be defined at the level where they will be
        # referenced, or else they
        # aren't available to other broken-out-and-included sub modules 
        # 
        # See https://cultivatehq.com/posts/ruby-constant-resolution/ for 
        # an explanation
        
        HTTPS_SCHEME = 'https'
        SSL_PORT = 443
        DFT_SSL_VERSION = 'TLSv1_2'

        DFT_OPEN_TIMEOUT = 60
        DFT_TIMEOUT = 60

        # the entire API is at this path
        RSRC_VERSION = 'v2'

        # Only these variables are displayed with PrettyPrint
        # This avoids displaying lots of extraneous data
        PP_VARS = %i[
          @name
          @connected
          @open_timeout
          @timeout
          @connect_time
        ].freeze

        # This module defines constants related to API connctions, used throughout
        # the connection class and elsewhere.
        ##########################################
        module Constants

          def self.included(includer)
            Xolo.verbose_include(includer, self)
          end

        end # module

      end # class

    end # Title Editor

  end # module Server

end # module Jamf
