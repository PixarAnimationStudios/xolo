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

# frozen_string_literal: true

# Gems
######

require 'zeitwerk'

# Xolo's Zeitwerk Config and processes
module XoloZeitwerkConfig

  # touch this file to make zeitwerk and mixins send text to stderr as things load
  # or get mixed in
  VERBOSE_LOADING_FILE = Pathname.new('/tmp/xolo-verbose-loading')

  # Or, set this ENV var to also make zeitverk and mixins send text to stderr
  VERBOSE_LOADING_ENV = 'XOLO_VERBOSE_LOADING'

  # touch this file to make zeitwek  eager-load everything when the gem is required.
  EAGER_LOAD_FILE = Pathname.new('/tmp/xolo-zeitwerk-eager-load')

  # Only look at the filesystem once.
  def self.verbose_loading?
    return @verbose_loading unless @verbose_loading.nil?

    @verbose_loading = VERBOSE_LOADING_FILE.file?
    @verbose_loading ||= ENV.include? VERBOSE_LOADING_ENV
    @verbose_loading
  end

  # rubocop: disable Style/StderrPuts
  def self.load_msg(msg)
    $stderr.puts msg if verbose_loading?    
  end
  # rubocop: enable Style/StderrPuts
      
  # The loader object for Xolo
  def self.loader
    @loader
  end

  # Configure the Zeitwerk loader, See https://github.com/fxn/zeitwerk
  # This all has to happen before the first 'module Xolo' declaration
  def self.setup_zeitwerk_loader(zloader)
    @loader = zloader

    # Ignore this file (more ignores below)
    loader.ignore __FILE__

    ##### Collaped Paths
    #
    # these paths all define classes & modules directly below 'Jamf'
    # If we didn't collapse them, then e.g.
    #   /jamf/api/base_classes/classic/group.rb
    # would be expected to define
    #   Jamf::Api::BaseClasses::Classic::Group
    # rather than what we want:
    #  Jamf::Group
    ###################################################

    # loader.collapse("#{__dir__}/jamf/api/classic")

    ##### Inflected Paths
    #
    # filenames => Constants, which don't adhere to zeitwerk's parsing standards.
    #
    # Mostly because the a filename like 'oapi_object' would be
    # loaded by zeitwerk expecting it to define 'OapiObject', but it really
    # defines 'OAPIObject'
    ###############################################

    # loader.inflector.inflect 'oapi_schemas' => 'OAPISchemas'  

    ##### Ingored Paths
    #
    # These should be ignored, some will be required directly
    ###############################################
    loader.ignore "#{__dir__}/ruby_extensions.rb"
    loader.ignore "#{__dir__}/ruby_extensions"
    loader.ignore "#{__dir__}/optimist.rb"

    ##### Callbacks
   
    # callback for when a specific file/constant loads
    # duplicate and uncomment this if desired to react to 
    # specific things loading 
    #####################################
    # loader.on_load('Xolo::SomeClass') do |klass, abspath|
    #   load_msg "I just loaded #{klass} from #{abspath}"
    # end

    # callback for when anything loads
    #  - const_path is like "Xolo::SomeClass" or "Xolo::SomeClass::SOME_CONST_ARRY"
    #  - value is the value that constant contains after loading,
    #    e.g. the class Xolo::SomeClass for 'Xolo::SomeClass' or
    #    an Array for the constant  "Xolo::SomeClass::SOME_CONST_ARRY"
    #  - abspath is the full path to the file where the constant was loaded from.
    #####################################
    loader.on_load do |const_path, value, abspath|
      load_msg "Zeitwerk just loaded #{value.class} '#{const_path}' from:\n  #{abspath}"
    end

    # actually do the setup that was defined above
    loader.setup
  end # setup_zeitwerk_loader

  # For testing the Zeitwrk Loader.
  # Normally we want autoloading on demand,
  # eager loading loads everything so we can see it
  #
  # To make this happen touch the file defined in ZEITWERK_EAGER_LOAD_FILE
  # in jamf.rb
  def self.eager_load_for_testing
    return unless EAGER_LOAD_FILE.file?

    loader.eager_load(force: true)
    warn :loaded
    # rescue Zeitwerk::NameError => e
    #   warn e.message
  end

end # module ZeitwerkConfig
