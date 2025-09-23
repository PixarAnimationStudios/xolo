# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

# frozen_string_literal: true

# Requires
#########################################

# This file is the entry point for loading the Xolo Admin code
#
# You can and should require the convenience file 'xolo-admin.rb'
#
#    require 'xolo-admin'
#

# Standard Libraries
######
require 'openssl'

# Monkeypatch OpenSSL::SSL::SSLContext to ignore unexpected EOF errors
# happens with openssl v3 ??
# see https://stackoverflow.com/questions/76183622/since-a-ruby-container-upgrade-we-expirience-a-lot-of-opensslsslsslerror
if OpenSSL::SSL.const_defined?(:OP_IGNORE_UNEXPECTED_EOF)
  OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
end

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

# Xolo Admin code - order matters here
# more loaded below
require 'xolo/core'
require 'xolo/admin/configuration'

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

# the rest of the Xolo Admin code - order matters here
require 'xolo/admin/credentials'

require 'xolo/admin/title'
require 'xolo/admin/version'

require 'xolo/admin/options'
require 'xolo/admin/interactive'
require 'xolo/admin/command_line'
require 'xolo/admin/processing'
require 'xolo/admin/progress_history'
require 'xolo/admin/validate'

require 'xolo/admin/connection'
require 'xolo/admin/cookie_jar'
require 'xolo/admin/jamf_pro'
require 'xolo/admin/title_editor'

# A small monkeypatch that allows Readline completion
# of Highline.ask to optionally use a prompt and be
# case insensitive
require 'xolo/admin/highline_terminal'
