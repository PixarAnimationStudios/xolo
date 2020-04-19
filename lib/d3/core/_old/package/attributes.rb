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

        ############### Instance Attributes #################

    # Note - I was tempted to set these up programmatically
    # using the keys of the P_FIELDS hash.
    # While that would make adding and removing field definitions
    # simpler, in that changes would be automatically reflected here,
    # It would also make the code less readable, more convoluted,
    # harder to document, and the documentation harder to read.
    # So here and in other places we're compromising DRY programming
    # for more human-usable code.
    #

    # See also, the attributes mixed in from D3::title

    # @return [Array<Hash>] the apple receipt data for the items installed by this pkg.
    #   When .[m]pkgs are installed, their identifiers and metadata are recorded in the OS's receipts database
    #   and are accessible via the pkgutil command. (e.g. pkgutil --pkg-info com.company.application). Storing it
    #   in the DB allows us to do uninstalls and other client tasks without needing to index the pkg in Casper.
    #   Each hash has these keys:
    #   - :apple_pkg_id => String
    #   - :version => String
    #   - :installed_kb => Integer
    attr_reader :apple_receipt_data

    # @return [Time] when was this package was added to d3
    attr_reader :added_date

    # @return [String,nil] the login name of the admin who added this packge to d3
    attr_reader :added_by

    # @return [Time,nil] when was this package made live in d3
    attr_reader :release_date

    # @return [String,nil] the login name of the admin who made it live
    attr_reader :released_by

    # @return [Boolean] does this pkg get installed automatically on all non-exluded clients?
    attr_reader :standard

    # @return [Array] a list of JSS::ComputerGroup names whose members get this
    #   package installed automatically
    attr_reader :auto_groups

    # @return [Array] a list of JSS::ComputerGroup ids for whose members this
    #   package is not available without force
    attr_reader :excluded_groups

    # @return [Boolean] should any currently installed versions of this title
    #   be uninstalled (if possible) before installing this package?
    attr_reader :remove_first

    # @return [Integer,nil] the JSS::Script id of the pre-install script, if any
    attr_reader :pre_install_script_id

    # @return [Integer,nil] the JSS::Script id of the post-install script, if any
    attr_reader :post_install_script_id

    # @return  [Integer,nil] the JSS::Script id of the pre-remove script, if any
    attr_reader :pre_remove_script_id

    # @return [Integer,nil] the JSS::Script id of the post-remove script, if any
    attr_reader :post_remove_script_id

    # @return [Boolean] does this pkg exist in the d3 pkg table?
    attr_reader :in_d3

    # @return [Symbol] the current status of the pkg in d3
    attr_reader :status

    # @return [Boolean] true specifies a patch that can be installed by itself.
    # false specifies a patch that must be installed incrementally.
    attr_reader :standalone

  end # class Package
end # module D3
