# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

# frozen_string_literal: true

# Load the core xolo functionality
#
# This is done automatically when you `require 'xolo/admin'` or
# `require 'xolo/server'`

# Ruby Standard Libraries
######
require 'English'
require 'date'
require 'time'
require 'pathname'
require 'json'

# Other Gems to include at this level
require 'pixar-ruby-extensions'

# Internal requires
require 'xolo/core/base_classes/configuration'
require 'xolo/core/base_classes/server_object'
require 'xolo/core/base_classes/title'
require 'xolo/core/base_classes/version'
require 'xolo/core/constants'
require 'xolo/core/exceptions'
require 'xolo/core/json_wrappers'
require 'xolo/core/loading'
require 'xolo/core/output'
require 'xolo/core/version'

# The main module
module Xolo

  extend Xolo::Core::Loading
  include Xolo::Core::Version
  include Xolo::Core::Constants
  include Xolo::Core::Exceptions

end # module Xolo
