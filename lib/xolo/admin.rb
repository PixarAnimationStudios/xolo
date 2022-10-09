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

# Yes we're using a OpenStruct for our @opts, even though it's very slow.
# It isn't so slow that it's a problem for processing a CLI tool.
# The benefit is being able to use either Hash-style references
# e.g. opts[key] or method-style when you know the key e.g. opts.title_id

module Xolo

  module Admin

    def self.executable=(path)
      @executable = Pathname.new path
    end

    def self.executable
      @executable
    end

    def self.usage
      @usage ||= "#{executable.basename} [global-options] command title-id [version] command-options"
    end

  end

end
