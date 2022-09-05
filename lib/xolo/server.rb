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

# frozen_string_literal: true

# This file is the entry point for loading the Xolo Server.
#
# one never does: 
#    require 'xolo' 
#
# but rather one of:
#    require 'xolo/server'
#    require 'xolo/client'
#    require 'xolo/admin'

# The Xolo Server is the focal point for a Xolo installation.
# It centralizes and standardizes call communication between
# the parts of Xolo:
#
# - A Jamf Pro server
# - A Jamf Title Editor server
# - The Xolo Admin application
# 
# The Xolo Client application running on managed Macs doesn't 
# talk directly to the Xolo server, it does all its work via Jamf Pro.

# Standard Libraries
######
require 'pathname'

# Gems
######

# Manual loading
######

# The main module
module Xolo

  module Server; end

end # module Xolo
