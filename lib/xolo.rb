# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

# frozen_string_literal: true

# This file sets up zeitwerk and loads the core module
#    require 'xolo'
#
# After requiring, do one of these
#    require 'xolo/server'
#    require 'xolo/client'
#    require 'xolo/admin'

# Ruby Standard Libraries
######
require 'English'
require 'date'
require 'pathname'
require 'json'

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
  include Xolo::Core::Version

end # module Xolo

# Manual Xolo loading
######
# put things here that aren't loaded by zeitwerk

# testing zeitwerk loading, if the correct file is present
XoloZeitwerkConfig.eager_load_for_testing
