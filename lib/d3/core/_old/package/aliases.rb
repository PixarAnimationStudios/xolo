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

    ############### Method Aliases #################

    # (intermixing them seems to make YARD documentation unhappy)
    alias standard? standard
    alias remove_first? remove_first

    # aliases for getting the script names
    alias pre_install pre_install_script_name
    alias post_install post_install_script_name
    alias pre_remove pre_remove_script_name
    alias post_remove post_remove_script_name


    alias pre_install_id pre_install_script_id
    alias post_install_id post_install_script_id
    alias pre_remove_id pre_remove_script_id
    alias post_remove_id post_remove_script_id


    # aliases for assigning scripts, since assignment methods
    # can take ids, names, or paths
    # clean these up someday!
    alias pre_install_script= pre_install=
    alias post_install_script= post_install=
    alias pre_remove_script= pre_remove=
    alias post_remove_script= post_remove=

    alias pre_install_script_id= pre_install=
    alias post_install_script_id= post_install=
    alias pre_remove_script_id= pre_remove=
    alias post_remove_script_id= post_remove=

    alias pre_install_script_name= pre_install=
    alias post_install_script_name= post_install=
    alias pre_remove_script_name= pre_remove=
    alias post_remove_script_name= post_remove=


    alias release make_live

    alias description notes
    alias description= notes=
    alias package_name name
    alias package_name= name=

    alias bom index
    alias file_list installed_files
    alias files installed_files


  end # class Package
end # module D3
