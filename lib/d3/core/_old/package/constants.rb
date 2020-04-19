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

   ############### Class Constants #################

    # A short name for the d3 packages table definition
    P_TABLE = D3::Database::PACKAGE_TABLE

    # A short name for the title table field definitions
    P_FIELDS = P_TABLE[:field_definitions]

    # the possible types of scripts associated with a d3 pkg
    SCRIPT_TYPES = [:pre_install, :post_install, :pre_remove, :post_remove]

    # the default expiration is to never expire
    DFT_EXPIRATION_DAYS = 0

    # These are the kinds of pkgs we can deal wth
    # note that :pkg means all flavors, including .mpkg's
    PKG_TYPES = [:pkg, :dmg]

    # d3 allows indexing, so here's the MySQL table that holds the
    # package indices
    PKG_CONTENTS_TABLE = "package_contents"

    # This regular expression matches valid (m)pkg filenames
    PKG_RE = /\.m?pkg$/

    # default status is :pilot
    DEFAULT_STATUS = :pilot

  end # class Package
end # module D3
