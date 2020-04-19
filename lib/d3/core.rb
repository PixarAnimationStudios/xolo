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

# This file requires the core pieces of d3 - code that is shared by all parts
# of it, both client tools and the server.

# Gems
###################

# jss requires lots of libs that we want, like
# English, open-uri, json, shellwords and so on
require 'jss'

# Standard Libraries
###################
require 'logger'
require 'tempfile'
require 'singleton'
require 'shellwords'


# Our stuff
###################
require 'd3/version'
require 'd3/core/utility'
require 'd3/core/exceptions'
require 'd3/core/constants'
require 'd3/core/ruby_extensions'
require 'd3/core/abstract_title'
require 'd3/core/abstract_version'
