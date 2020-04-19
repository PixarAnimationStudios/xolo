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

module D3

  # A version available in a title in d3.
  #
  # This file defines values and methods used in all parts of d3
  #
  class AbstractVersion

    # Mixins
    #################

    # versions are comparable via their id - newer ones always have higher ids
    include Comparable

    # Constants
    #################
    STATUS_PILOT = 'pilot'.freeze
    STATUS_RELEASED = 'released'.freeze
    STATUS_SKIPPED = 'skipped'.freeze
    STATUS_DEPRECATED = 'deprecated'.freeze

    STATUSES = [
      STATUS_PILOT,
      STATUS_RELEASED,
      STATUS_SKIPPED,
      STATUS_DEPRECATED
    ].freeze

    # Attributes
    #################

    #### D3 Attributes

    # @return [Integer] unique id for this version, chronologically ascending
    #   based on creation time, but no possibility of duplicates
    attr_reader :id

    # @return [Time] when was this version was added to d3
    attr_reader :added_date

    # @return [String,nil] the login name of the admin who added this version
    attr_reader :added_by

    # @return [Time,nil] when was this version made live in d3
    attr_reader :release_date

    # @return [String,nil] the login name of the admin who made it live
    attr_reader :released_by

    # @return [Time] when was this version was modified
    attr_reader :last_modified

    # @return [String,nil] the login name of the admin who last modified this version
    attr_reader :modified_by

    # @return [Boolean] should any currently installed versions of this title
    #   be uninstalled (if possible) before installing this version?
    attr_reader :remove_first
    alias remove_first? remove_first

    # @return [Integer,nil] the JSS::Script id of the pre-install script
    attr_reader :pre_install_script_id

    # @return [Integer,nil] the JSS::Script id of the post-install script
    attr_reader :post_install_script_id

    # @return  [Integer,nil] the JSS::Script id of the pre-remove script
    attr_reader :pre_remove_script_id

    # @return [Integer,nil] the JSS::Script id of the post-remove script
    attr_reader :post_remove_script_id

    # @return [Array<Hash>] the apple receipt data for the package installed
    #   by this version.
    #   When .[m]pkgs are installed, their identifiers and metadata are
    #   recorded in the OS's receipts database and are accessible via the
    #   pkgutil command. (e.g. pkgutil --pkg-info com.company.application).
    #   Storing it in the DB allows us to do uninstalls and other client
    #   tasks without needing to index the pkg in Casper.
    #   Each hash has these keys:
    #   - :apple_pkg_id => String
    #   - :version => String
    #   - :installed_kb => Integer
    attr_reader :apple_receipt_data

    ##### Jamf Package attributes

    # @return [Boolean] the allow_uninstalled pkg attr
    attr_reader :removable
    alias removable? removable

    # @return [Boolean] the reboot_required pkg attr
    attr_reader :reboot_required
    alias reboot_required? reboot_required

    #### Jamf Patch Attributes

    # @return [String] The unique name of the title containing this version
    attr_reader :title

    # @return [String] the version number of this version, e.g. 1.2.3b4
    #   Must be unique in the title
    attr_reader :version

    # @return [Symbol] whats the d3 status of this version. One of the values
    #   of D3::Version::STATUSES
    attr_reader :status

    # @return [String] the minimum OS version that can install this version
    attr_reader :minimum_os

    # @return [String] the maximum OS version that can install this version
    attr_reader :maximum_os

    # @return [Integer,nil] the JSS package id assigned to the version
    attr_reader :package_id

    # @return [Array<D3::KillApp>] The killapps for
    #   the version
    attr_reader :killapps

    # @return [Boolean] true means this version can be installed by itself.
    #   false specifies a version that must be installed incrementally.
    attr_reader :standalone
    alias standalone? standalone

    # @return [D3::Criteria] Criteria indicating which computers have this
    #  version of this title installed.
    attr_reader :installed_criteria
    alias components installed_criteria

    # @return [D3::Criteria] The criteria defining which computers may
    #   install this version.
    attr_reader :eligibility_criteria
    alias capabilities eligibility_criteria

    # @return [D3::Criteria] Currently not used.
    # attr_reader :dependencies

    # When creating a new version to be created on the server, via .new,
    # initialization requires a an existing title:, a unique version:
    # to add to the title, and the name of the admin: who's adding it
    #
    # Other required data must be added later and will be validated before
    # saving. (This never happens on the server, such to-be-created titles are
    # passed to it as JSON via https)
    #
    # When instantiating via JSON passed over https, the JSON string must be
    # in the from_json: param, which is the only param needed.
    #
    # The server itself only ever initializes from JSON passed by d3admin for
    # creating and updating titles & versions. Existing versions are stored
    # locally as YAML, and are loaded fully initialized.
    #
    def initialize(**params)
      # Here we go!

      # Init from JSON - this happens more than not, both on the server
      # and on clients
      if params[:from_json]
        init_from_json params[:from_json]
        return
      end

      JSS::Validate.non_empty_string params[:title], 'title: String required.'
      D3::Title.validate_title_exists params[:title]

      JSS::Validate.non_empty_string params[:version], 'version: String required.'
      self.class.validate_unique_version params[:title], params[:version]

      @title = params[:title]
      @version = params[:version]
      @status = STATUS_PILOT
      @killapps = []
      @apple_receipt_data = []

      # this will hold changes to be recorded in the changelog
      # when the title is saved
      # Hash keys are attrib names, values are hashes
      # with keys orig: and new:
      @changes = {}
    end # init

    ############### Public Instance Methods #################

    # a unique textual identifier for this version
    # The title and version joined by a '-'
    # TODO: revisions?
    #
    # @return [String] the edition
    #
    def edition
      @edition ||= "#{title}-#{version}"
    end

    # Is the status :pilot?
    #
    # @return [Boolean]
    #
    def pilot?
      status == STATUS_PILOT
    end

    # Is the status :live?
    #
    # @return [Boolean]
    #
    def released?
      status == STATUS_RELEASED
    end

    def skipped?
      status == STATUS_SKIPPED
    end

    # Is the status :deprecated?
    #
    # @return [Boolean]
    #
    def deprecated?
      status == STATUS_DEPRECATED
    end

    def package_assigned?
      !package_id.nil?
    end

    def package
      return nil unless package_assigned?
    end

    # Use Comparable to give sortability
    # and equality.
    #
    def <=>(other)
      id <=> other.id
    end # <=>

    # @return [String] The JSON data for network transfer of this object
    #
    def to_json
      JSON.pretty_generate(
        id: id,
        title: title,
        version: version,
        minimum_os: minimum_os,
        maximum_os: maximum_os,
        package_id: package_id,
        killapps: killapps.map(&:json_data),
        added_date: (added_date ? added_date.iso8601 : nil),
        added_by: added_by,
        release_date: (release_date ? release_date.iso8601 : nil),
        released_by: released_by,
        status: status,
        remove_first: remove_first,
        pre_install_script_id: pre_install_script_id,
        post_install_script_id: post_install_script_id,
        pre_remove_script_id: pre_remove_script_id,
        post_remove_script_id: post_remove_script_id,
        apple_receipt_data: apple_receipt_data,
        changes: @changes,
        standalone: standalone,
        installed_criteria: installed_criteria.criteria,
        eligibility_criteria: eligibility_criteria.criteria
      )
    end

    private

    def init_from_json(from_json)
      @id = from_json[:id]
      @title = from_json[:title]
      @version = from_json[:version]
      @minimum_os = from_json[:minimum_os]
      @maximum_os = from_json[:maximum_os]
      @package_id = from_json[:package_id]
      @added_date = Time.parse from_json[:added_date] if from_json[:added_date]
      @added_by = from_json[:added_by]
      @release_date = Time.parse from_json[:release_date] if from_json[:release_date]
      @released_by = from_json[:released_by]
      @status = from_json[:status].to_sym
      @pre_install_script_id = from_json[:pre_install_script_id]
      @post_install_script_id = from_json[:post_install_script_id]
      @pre_remove_script_id = from_json[:pre_remove_script_id]
      @post_remove_script_id = from_json[:post_remove_script_id]
      @apple_receipt_data = from_json[:apple_receipt_data]
      @killapps = from_json[:killapps].map { |ka| D3::Killapp.new ka }
      @killapps ||= []
      @apple_receipt_data = from_json[:apple_receipt_data]
      @apple_receipt_data ||= []
      @changes = from_json[:changes] ? from_json[:changes] : {}
      @standalone = from_json[:standalone]
      @installed_criteria = D3::Criteria.new from_json: from_json[:installed_criteria]
      @eligibility_criteria = D3::Criteria.new from_json: from_json[:eligibility_criteria]
    end

  end # class version

end # module D3
