# Copyright 2025 Pixar
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

require 'xolo'

require 'highline'

# Use optimist for CLI option processing
# https://rubygems.org/gems/optimist
#
# This version modified to allow 'insert_blanks' which
# puts blank lines between each option in the help output.
# See comments in the required file for details.
#
require 'optimist_with_insert_blanks'

# A small monkeypatch that allows Readline completion
# of Highline.ask to optionally use a prompt and be
# case insensitive
require 'xolo/admin/highline_terminal'

# Yes we're using a OpenStruct for our @opts, even though it's very slow.
# It isn't so slow that it's a problem for processing a CLI tool.
# The benefit is being able to use either Hash-style references
# e.g. opts[key] or method-style when you know the key e.g. opts.title
require 'ostruct'
require 'io/console'

module Xolo

  module Client

    # Constants
    ########################
    ########################

    EXECUTABLE_FILENAME = 'xolo'

  end

end
