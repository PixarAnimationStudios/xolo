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

require 'openssl'
require 'faraday'
require 'faraday/multipart'
require 'highline'

# Monkeypatch OpenSSL::SSL::SSLContext to ignore unexpected EOF errors
# happens with openssl v3 ??
# see https://stackoverflow.com/questions/76183622/since-a-ruby-container-upgrade-we-expirience-a-lot-of-opensslsslsslerror
if OpenSSL::SSL.const_defined?(:OP_IGNORE_UNEXPECTED_EOF)
  OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
end

# Yes we're using a OpenStruct for our @opts, even though it's very slow.
# It isn't so slow that it's a problem for processing a CLI tool.
# The benefit is being able to use either Hash-style references
# e.g. opts[key] or method-style when you know the key e.g. opts.title
require 'ostruct'
require 'open3'
require 'singleton'
require 'yaml'
require 'shellwords'
require 'tempfile'
require 'readline'
require 'io/console'

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

module Xolo

  module Admin

    # Constants
    ##########################
    ##########################

    EXECUTABLE_FILENAME = 'xadm'

    # if a streaming line contains this text, we bail out instead of
    # continuing any processing
    STREAMING_OUTPUT_ERROR = 'ERROR'

    # Module Methods
    ##########################
    ##########################

    # when this module is included
    def self.included(includer)
      Xolo.verbose_include includer, self
    end

    # Instance Methods
    ##########################
    ##########################

    # @return [String] the usage
    ########################
    def usage
      @usage ||= "#{EXECUTABLE_FILENAME} [global-options] command [target] [command-options]"
    end

    def config
      Xolo::Admin::Configuration.instance
    end

  end

end
