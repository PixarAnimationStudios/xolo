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
module D3

  module PuppyTime

    #
    # PendingPuppy - a d3 pkg awaiting installation during puppytime.
    #
    class PendingPuppy

      ############### Mixin Modules #################

      # The D3::title module provides common attributes and methods related to
      # d3's use of 'titles'
      include D3::title

      ############### Attributes #################

      # @return [Boolean] was this puppy queued with force?
      attr_reader :force

      # @return [Time] when was this puppy added to the queue
      attr_accessor :queued_at

      # @return [Integer] the expiration period for this app
      attr_reader :custom_expiration

      ############### Constructor #################

      # We don't need much data about the pkg to be installed
      # These are required in the args:
      #    :title
      #    :version
      #    :revision
      #    :admin
      #    :status
      # These are optional:
      #    :force - use force when installing
      #
      def initialize (args = {})
        raise JSS::MissingDataError, "Puppies need a :title" unless args[:title]
        raise JSS::MissingDataError, "Puppies need a :version" unless args[:version]
        raise JSS::MissingDataError, "Puppies need a :revision" unless args[:revision]
        raise JSS::MissingDataError, "Puppies need an :admin" unless args[:admin]
        raise JSS::MissingDataError, "Puppies need an :status" unless args[:status]

        @title = args[:title]
        @version = args[:version]
        @revision = args[:revision]
        @admin = args[:admin]
        @custom_expiration = args[:custom_expiration]
        @status = args[:status]

        @id =  D3::Package.ids_to_patchs.invert[patch]

        raise JSS::InvalidDataError, "patch #{patch} doesn't exist in d3." unless @id

        @force = args[:force]
      end # init

      # Install this puppy
      #
      # @return [void]
      #
      def install

        begin # for ensure

          install_args = {:puppywalk => true, :admin => @admin, :force => @force}
          install_args[:expiration] =  @custom_expiration if @custom_expiration

          # install it  - this will remove it from the queue if successful
          D3::Package.new(:patch => patch).install(install_args)
        ensure
          # but we need to remove it even if not successfull, so it doesn't
          # keep trying and failing (and reminding the users)
          D3::PuppyTime::PuppyQueue.instance - self
        end
      end # install

    end #class PendingPuppy
  end # module puppytime
end #module D3
