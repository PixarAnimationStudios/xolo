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

# This file sets up zeitwerk and loads the core module
#    require 'xolo'
#
# After requiring, do one of these
#    require 'xolo/server'
#    require 'xolo/client'
#    require 'xolo/admin'

# Core Standard Libraries
######
require 'English'
require 'date'

# Other Gems to include at this level
require 'pixar-ruby-extensions'

# Zeitwerk
######

# TODO: Encapsulate the ruby-jss zeitwerk loader stuff, like it is here.
# As written, it doesn't play with other gems (like this one) using Zeitwerk
# require 'ruby-jss'

# Configure the Zeitwerk loader, See https://github.com/fxn/zeitwerk
# This also defines other Xolo module methods related to loading
#
require 'xolo/zeitwerk_config'

# the `Zeitwerk::Loader.for_gem` creates the loader object, and must
# happen in this file, so we pass it into a method defined in
# zeitwerk_config
XoloZeitwerkConfig.setup_zeitwerk_loader Zeitwerk::Loader.for_gem

# The main module
module Xolo

  extend Xolo::Core::Loading
  include Xolo::Core::Constants
  include Xolo::Core::Exceptions
  extend Xolo::Core::Utility

  VERSION = Xolo::Core::Version::VERSION

  # the single instance of our configuration object
  def self.config
    Xolo::Core::Configuration.instance
  end

end # module Xolo

# Manual Xolo loading
######
# put things here that aren't loaded by zeitwerk

# testing zeitwerk loading, if the correct file is present
XoloZeitwerkConfig.eager_load_for_testing
