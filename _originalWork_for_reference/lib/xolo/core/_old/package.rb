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

  # Package - A JSS::Package that can be installed and maintained by d3
  #
  class Package < JSS::Package

    module Validate
    end # module validate

  end # class package

end # modle D3

require 'xolo/package/mixins'
require 'xolo/package/constants'
require 'xolo/package/class_variables'
require 'xolo/package/class_methods'
require 'xolo/package/attributes'
require 'xolo/package/constructor'
require 'xolo/package/validate'
require 'xolo/package/setters'
require 'xolo/package/getters'
require 'xolo/package/questions'
require 'xolo/package/server_actions'
require 'xolo/package/client_actions'
require 'xolo/package/private_methods'
require 'xolo/package/aliases'
