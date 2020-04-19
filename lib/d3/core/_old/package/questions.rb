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
  class Package < JSS::Package

    # @return [Boolean] Does this pkg have a pre-install script?
    def pre_install_script?
      not @pre_install_script_id.nil?
    end

    # @return [Boolean] Does this pkg have a post-install script?
    def post_install_script?
      not @post_install_script_id.nil?
    end

    # @return [Boolean] Does this pkg have a pre-remove script?
    def pre_remove_script?
      not @pre_remove_script_id.nil?
    end

    # @return [Boolean] Does this pkg have a post-remove script?
    def post_remove_script?
      not @post_remove_script_id.nil?
    end

    # @return [Boolean] Is this pkg in on the server?
    #
    def created?
      @in_jss and @in_d3
    end

    # @return [Boolean] Is this pkg on the server?
    #
    def saved?
      not (@need_to_update or @need_to_update_d3)
    end

    # @return [Boolean] Is this pkg in pilot? (saved, but never made live)
    #
    def deprecated?
      @status == :deprecated
    end

    # @return [Boolean] Is this pkg in pilot? (saved, but never made live)
    #
    def skipped?
      @status == :skipped
    end

    # @return [Boolean] Is this pkg installed on this machine via d3?
    #   Note: this overrides JSS::Package#installed?
    #
    def installed?
      D3::Client::Receipt.titles.include?(@title) and D3::Client::Receipt.all[@title].id == @id
    end

    # @return [Boolean] Does this pkg expire by default?
    #
    def expires?
      @expiration.to_i > 0 && @expiration_bundle_ids
    end

    # @return [Boolean] Is this pkg 'indexed' in the jss, so that it can be removable?
    #
    def indexed?
      not index.empty?
    end # indexed?



  end # class Package
end # module D3
