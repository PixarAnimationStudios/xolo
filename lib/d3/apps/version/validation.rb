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

module D3

  # Valication for versions as seen by the client apps
  #
  class Version < AbstractVersion

    # Methods for validating data in d3admin
    # Some validation methods just raise errors if things aren't right.
    #
    # Others take data in one form, and if it is valid, return it in a different
    # form.
    #
    # E.g. given a group name, if the group exists, its id is returned.
    # If not, an error is raised.
    #

    # Constants
    ##############################

    OS_VERS_ERR = 'OS version must be nil, an empty string, or in the form XX.XX[.XX] '.freeze

    PKG_EXT = '.pkg'.freeze

    # Class Methods
    #################################

    # raise error if a given version doesn't exist for a given title
    def self.validate_version_exists(title, version)
      raise JSS::NoSuchItemError, "No version '#{version}' for title #{title}" unless title_has_version?(title, version)
    end

    # raise error if a given version exists for a given title
    def self.validate_unique_version(title, version)
      raise JSS::AlreadyExistsError, "Version '#{version}' already exists for title '#{title}'" if title_has_version?(title, version)
    end

    def self.title_has_version?(title, version)
      all_for_title(title).map { |v| v[:version] }.include? version
    end

    # Private instance methods
    #########################
    private

    def validate_os_version(os_vers)
      return nil if os_vers.to_s.empty?
      JSS::Validate.non_empty_string os_vers, OS_VERS_ERR
      return os_vers if os_vers =~ /^\d\d\.\d\d?(\.\d\d?)?/
      raise JSS::InvalidDataError, OS_VERS_ERR
    end

    def valdate_killapp(killapp)
      raise 'killapps must be D3::KillApp objects' unless killapp.is_a? D3::KillApp
      killapp
    end

    # validate that a script name exists
    # return the id if so, raise error if not
    #
    # @param script[String] the name of a script
    #
    # @return [Integer] the id of the script
    #
    def validate_script(script)
      return nil if script.to_s.empty?
      id = JSS::Script.map_all_ids_to(:name).invert[script]
      return id if id
      raise JSS::NoSuchItemError, "No script '#{script}' in the JSS"
    end

    # validate that a package name exists
    # return the id if so, raise error if not
    #
    # @param script[String] the name of a package
    #
    # @return [Integer] the id of the package
    #
    def validate_package(pkg)
      raise ArgumentError, 'A package name must be provided'
      id = JSS::Package.map_all_ids_to(:name).invert[pkg]
      return id if id
      raise JSS::NoSuchItemError, "No package '#{pkg}' in the JSS"
    end

  end # class version

end # modle D3
