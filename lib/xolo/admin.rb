# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
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

    # @return [Xolo::Admin::Configuration] our config, available via the module
    ########################
    def self.config
      Xolo::Admin::Configuration.instance
    end

    # Instance Methods
    ##########################
    ##########################

    # @return [String] the usage
    ########################
    def usage
      @usage ||= "#{EXECUTABLE_FILENAME} [global-options] command [target] [command-options]"
    end

    # @return [Xolo::Admin::Configuration] our config available via the admin app instance
    ########################
    def config
      Xolo::Admin::Configuration.instance
    end

  end

end
