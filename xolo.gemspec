# Copyright 2023 Pixar
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

proj_name = 'xolo'
lib_dir = 'xolo'

require "./lib/#{lib_dir}/core/version"

Gem::Specification.new do |s|
  # General

  s.name        = proj_name
  s.version     = Xolo::Core::Version::VERSION
  s.authors     = ['Chris Lasell']
  s.email       = 'd3@pixar.com'
  s.homepage    = 'http://pixaranimationstudios.github.io/depot3/'
  s.license     = 'Nonstandard'
  s.date        = Time.now.utc.strftime('%Y-%m-%d')
  s.summary     = 'A package/patch management system for OS X which extends the capabilites of Jamf Pro.'
  s.description = <<~EODDESC
    Xolo is a kind of dog.
  EODDESC
  s.required_ruby_version = '>= 2.6.3'

  # files
  s.files = Dir['lib/**/*.rb']

  # executables
  s.executables << 'xadm'

  # Dependencies
  s.add_runtime_dependency 'pixar-ruby-extensions', '~>1.0'

  # Only for the server
  # s.add_runtime_dependency 'ruby-jss', '~>2.0'
  # s.add_runtime_dependency 'windu', '~>1.0'
end
