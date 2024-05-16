# Copyright 2024 Pixar
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

# frozen_string_literal: true

module Xolo

  module Server

    module Constants

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # Constants
      #####################################

      EXECUTABLE_FILENAME = 'xoloserver'

      # Sinatra App Environments

      APP_ENV_DEV = 'development'
      APP_ENV_TEST = 'test'
      APP_ENV_PROD = 'production'

      # Paths

      DATA_DIR = Pathname.new('/Library/Application Support/xoloserver')

      # streaming progress from the server.
      # When a line containing only this string shows up in a stream file
      # that means the stream is done, and no more lines will be sent.
      PROGRESS_COMPLETE = 'PROGRESS_COMPLETE'

    end # module Constants

  end #  Server

end # module
