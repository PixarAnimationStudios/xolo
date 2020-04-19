# Copyright 2018 Pixar
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
#
#

module Xolo

  # Methods for dealing with titles in the d3admin executable
  #
  class AdminApp

    # Add a new title to d3
    #
    # The title will be in @target
    #
    def add_title
      raise "Title '#{@target} already exists" if Xolo::Title.exist? @target

      @title = Xolo::Title.new name: @target, admin: @admin

      # create or update the title
      add_or_update_title

      puts 'Done!'
    end

    # Add a new title to d3
    #
    # The title will be in @target
    #
    def edit_title
      raise "No such title: '#{@target}" unless Xolo::Title.exist? @target

      @title = Xolo::Title.fetch @target

      # create or update the title
      add_or_update_title

      puts 'Done!'
    end

    def add_or_update_title
      # these setters perform validation
      @title.display_name = @action_opts.display_name
      @title.description = @action_opts.description
      @title.publisher = @action_opts.publisher
      @title.category = @action_opts.category
      @title.standard = @action_opts.standard
      @title.auto_groups = @action_opts.auto_group
      @title.excluded_groups = @action_opts.excluded_group
      @title.expiration = @action_opts.expiration
      @title.expiration_bundle_ids = @action_opts.expiration_bundle
      # TODO: confirmation unless @global_opts.auto_confirm
      @title.save
    end


  end # class AdminApp

end # module Xolo
