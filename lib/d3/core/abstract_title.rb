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

# require 'd3/core/title/version'

module D3

  # Title = a software title (formerly 'basename') available in d3 and
  # eventually Jamf Patch Management.
  #
  # This file defines commonality between Titles as they are handled on the
  # d3 server, and as they are used on d3 client tools (d3 and d3admin)
  #
  # In both contexts, D3::Title inherits from this class, but have different
  # behaviors as appropriate.
  #
  # All setters are defined in the client-specific title.rb, since the server
  # doesn't need them.
  #
  # Both subclasses will define the following methods:
  #
  #   - Title.fetch
  #   - Title#create, Title#update, Title#delete
  #
  # The server Titles will use those to interact with the server data store
  # The client Titles will use those to interact with the server via HTTPS.
  #
  class AbstractTitle

    # Constants
    ##############################

    DFT_EXPIRATION = 0
    DFT_DEADLINE = 0
    DFT_GRACE_PERIOD = 15

    SELF_SVC_NOTIF_OPTIONS = %w[none ssvc nctr both].freeze

    # Attributes
    ##############################

    # @return [String] a unique name for this title in d3.
    #   Can only contain alphanumerics and underscores.
    #   For titles provided by d3server's PatchExternalSource to the JSS,
    #   this becomes the 'name_id'. Titles from other PatchSources provide
    #   their own name_id to the JSS, which is available in the jss_name_id,
    #   and unrelated to the name here.
    #
    #   NOTE: required for creation with .make and cannot be changed after that.
    #   @seealso: {#display_name}
    #
    attr_reader :name

    # Attributes of titles NOT hosted by d3
    #################

    # @return [Integer] the id of the JSS::PatchSource that holds this title.
    #   or :d3 if d3 is the patch source
    attr_reader :jss_patch_source_id

    # @return [String] the name of the AutoPkg recipe that fetches and builds
    #   the package for updates to this title. nil if not in autopilot
    attr_reader :autopkg_recipe

    # NOTE: autopkg_recipe_contents has custom getters in the subclasses.

    # Attributes of titles hosted by d3
    #################

    # @return [String] Publisher of the title.
    attr_reader :publisher

    # @return [D3::Criteria] The criteria used to determine which managed computers
    #   have any version of this Title installed
    attr_reader :installed_criteria
    alias requirements installed_criteria

    # NOTE: ext_attrs has a custom getter below that returns a frozen dup
    # of the array

    # Attributes of all titles
    #################

    # @param desc [String] A description of this title.
    #
    #   NOTE: Descriptions should be meaningful. Counter-example: in a title
    #   named 'foo', the description 'Installs foo' is useless. Please
    #   provide useful info *about* foo for those who don't know what it is,
    #   where it's from, or why it's here.
    #
    # @return [String]
    #
    attr_reader :description

    # @return [String] The Category for this title - used in
    # packages, scripts and policies (for Self Service), can be nil.
    attr_reader :category

    # @return [Array<Integer>] a list of JSS::ComputerGroup names whose members
    #   get this version installed automatically when piloted
    attr_reader :pilot_group_ids

    # @return [Boolean] does this title get installed automatically on all
    #   non-excluded macs?
    attr_reader :standard
    alias standard? standard

    # @return [Array<Integer>] a list of JSS::ComputerGroup names whose members
    #   get this version installed automatically when released
    attr_reader :auto_group_ids

    # @return [Array<Integer>] a list of JSS::ComputerGroup ids for whose
    #   members this version is not available without force
    attr_reader :excluded_group_ids

    # @return [Integer] the days of disuse before an expirable version expires.
    # 0 = never
    attr_reader :expiration

    # @return [Array<String>] the bundle ids that need come to
    # the foreground to prevent expiration
    attr_reader :expiration_bundle_ids

    # Self Service attributes
    #####

    # @return [Boolean] is this title in self service?
    attr_reader :in_self_service

    # NOTE: display_name has an explicit getter below

    # NOTE: the icon is write-only, see the web-ui code for icon-read/display.

    # @return [Symbol] how to notify users of title availability
    # one of :none, :ssvc, :nc, :both
    attr_reader :notify

    # @return [Boolean] re-notify all in-scope clients when changing settings
    attr_reader :resend

    ### Initial SSvc installs

    # @return [Boolean] feature title in SSvc main page?
    attr_reader :feature

    # @return [Array<String>] feature title in these SSvc category pages
    attr_reader :feature_categories

    # @return [String] if notification is on, the notifcation subject for
    #  initial installation
    attr_reader :notify_install_subj

    # @return [String] if notification is on, the notifcation message for
    #  initial installation
    attr_reader :notify_install_msg

    ### update SSvc installs

    # @return [String] if notification is on, the notifcation subject for
    #  update installation
    attr_reader :notify_update_subj

    # @return [String] if notification is on, the notifcation message for
    #  update installation
    attr_reader :notify_update_msg

    # Update Deadlines
    #####

    # @return [Integer] number of days before updates are force-installed
    #  zero = no deadline
    attr_reader :deadline

    # @return [Integer] number of minutes user has to quit apps, once deadline
    #   arrives.
    attr_reader :grace_period

    # @return [String] Subject of grace period warning telling user to quit apps
    attr_reader :grace_subj

    # @return [String] Body of grace period warning telling user to quit apps
    attr_reader :grace_msg

    # General Jamf Patch Mgmt attributes
    #####

    # @return [Integer] the id of this title as a JSS::PatchTitle
    attr_reader :jss_id

    # @return [String] the name_id of the title on it's JSS::PatchSource.
    #   If we are the PatchSource, then it matches the name of this title.
    attr_reader :jss_name_id

    # D3 housekeeping attributes
    #####

    # @return [Time] When the title was added to d3
    attr_reader :added_date

    # @return [Time] Who added the title to d3
    attr_reader :added_by

    # @return [Time] the last time this title, or any of its versions, were changed
    # TODO: inmplement setter from versions.
    attr_accessor :last_modified

    # @return [Time] the admin who made the last modification
    # TODO: inmplement setter from versions.
    attr_accessor :modified_by

    # @return [String] The version most recently added
    attr_reader :latest_version

    # @return [String, nil] The currently released version
    attr_reader :released_version

    # Initial Install Policies
    #####

    # @return [Integer] The id of the policy that installs this title
    #    on-demand (either manually or via SSvc)
    attr_reader :on_demand_policy_id

    # #return [Integer] The id of the policy that installs this title
    #   automatically, scoped to pilot-groups
    # TODO: this belongs to the version, not the title
    # Since there may be more than one version in pilot at a time.
    # attr_reader :pilot_install_policy_id

    # @return [Integer] The id of the policy that installs this title
    #   automatically, scoped to auto-groups
    attr_reader :auto_install_policy_id

    # When instantiating a new title to be created on the server, via .new,
    # initialization requires a unique name: and an admin:
    # Other required data must be added later and will be validated before
    # saving. (This never happens on the server, such to-be-created titles are
    # passed to it as JSON via https)
    #
    # When instantiating via JSON passed over https, the JSON string must be
    # in the from_json: param, which is the only param needed.
    #
    # The server itself only ever initializes from JSON passed by d3admin for
    # creating and updating titles. Existing titles are stored locally as
    # YAML, and are loaded fully initialized.
    #
    def initialize(**params)
      # Here we go!

      # Init from JSON - this happens more than not, both on the server
      # and on clients
      if params[:from_json]
        init_from_json params[:from_json]
        return
      end

      # if not from json, then we are being called from .new,
      # to creating a new title in d3, in which case we must have a
      # unique name. all other attributes are set via
      # setters later.
      #
      # This only happens from d3admin CLI or web

      @name = validate_name params[:name]

      # set empty collections
      @extension_attributes = []
      @pilot_group_ids = []
      @auto_group_ids = []
      @excluded_group_ids = []
      @expiration_bundle_ids = []
      @feature_categories = []
      @installed_criteria = D3::Criteria.new

      # set other defaults
      @expiration = DFT_EXPIRATION
      @deadline = DFT_DEADLINE
      @grace_period = DFT_GRACE_PERIOD
      @notify = :none

      # this will hold changes to be recorded in the changelog
      # when the title is saved
      # Hash keys are attrib names, values are hashes
      # with keys orig: and new:
      @changes = {}
    end

    # @return [String] a human-friendly name for this title, with any characters
    #  defaults to the name if nil
    #
    def display_name
      @display_name || @name
    end

    # @return [Array<String>] The names of d3 Patch ExtensionAttributes used
    # by this title. This returns a frozzen dup of the actual array - changes
    # to it must be made with the add_ext_attr and remove_ext_attr methods
    # defined in clients/title.rb
    # TODO: Do we make d3admin able to create/edit EAs, or a separate tool?
    def ext_attrs
      arr = @extension_attributes.dup
      arr.each(&:freeze)
      arr.freeze
    end

    # everything needed to re-create an instance.
    # This is how objects are passed between server and clients
    def to_json
      {
        name: name,

        # non-d3-hosted
        jss_patch_source_id: jss_patch_source_id,
        autopkg_recipe: autopkg_recipe,

        # d3-hosted
        publisher: publisher,
        installed_criteria: installed_criteria.criteria,
        ext_attrs:  @extension_attributes.map(&:json_data),

        # all titles - general
        description: description,
        category: category,
        pilot_group_ids: pilot_group_ids,
        standard: standard,
        auto_group_ids: auto_group_ids,
        excluded_group_ids: excluded_group_ids,
        expiration: expiration,
        expiration_bundle_ids: expiration_bundle_ids,
        on_demand_policy_id: on_demand_policy_id,
        auto_install_policy_id: auto_install_policy_id,

        # all titles - SSvc
        in_self_service: in_self_service,
        display_name: display_name,
        notify: notify,
        resend: resend,
        feature: feature,
        feature_categories: feature_categories,
        notify_install_subj: notify_install_subj,
        notify_install_msg: notify_install_msg,
        notify_update_subj: notify_update_subj,
        notify_update_msg: notify_update_msg,

        # all titles - update deadlines
        deadline: deadline,
        grace_period: grace_period,
        grace_subj: grace_subj,
        grace_msg: grace_msg,

        # all titles - General Jamf Patch Mgmt
        jss_id: jss_id,
        jss_name_id: jss_name_id,

        # all titles - D3 housekeeping
        added_date:  (added_date ? added_date.iso8601 : nil),
        added_by: added_by,
        last_modified: (last_modified ? last_modified.iso8601 : nil),
        modified_by: modified_by,
        latest_version: latest_version,
        released_version: released_version,

        # all titles - changelog
        changes: @changes
      }.to_json
    end

    private

    # Parse data recieved from server or client into an instance.
    #
    # Note that the json here is not raw, it has already been parsed
    # by JSON.d3parse
    def init_from_json(from_json)
      # set empty collections
      from_json[:ext_attrs] ||= []
      from_json[:pilot_group_ids] ||= []
      from_json[:auto_group_ids] ||= []
      from_json[:excluded_group_ids] ||= []
      from_json[:expiration_bundle_ids] ||= []
      from_json[:feature_categories] ||= []
      from_json[:changes] ||= {}

      @name = from_json[:name]

      # non-d3-hosted
      @jss_patch_source_id = from_json[:jss_patch_source_id]
      @autopkg_recipe = from_json[:autopkg_recipe]

      # d3-hosted
      @publisher = from_json[:publisher]
      @installed_criteria = D3::Criteria.new from_json: from_json[:installed_criteria]
      @extension_attributes = from_json[:ext_attrs].map { |ea| D3::ExtensionAttribute.new from_json: ea }

      # all titles - general
      @description = from_json[:description]
      @category = from_json[:category]
      @pilot_group_ids = from_json[:pilot_group_ids]
      @standard = from_json[:standard]
      @auto_group_ids = from_json[:auto_group_ids]
      @excluded_group_ids = from_json[:excluded_group_ids]
      @expiration = from_json[:expiration]
      @expiration_bundle_ids = from_json[:expiration_bundle_ids]
      @on_demand_policy_id = from_json[:on_demand_policy_id]
      @auto_install_policy_id = from_json[:auto_install_policy_id]

      # all titles - SSvc
      @in_self_service = from_json[:in_self_service]
      @display_name = from_json[:display_name]
      @notify = from_json[:notify].to_sym
      @resend = from_json[:resend]
      @feature = from_json[:feature]
      @feature_categories = from_json[:feature_categories]
      @notify_install_subj = from_json[:notify_install_subj]
      @notify_install_msg = from_json[:notify_install_msg]
      @notify_update_subj = from_json[:notify_update_subj]
      @notify_update_msg = from_json[:notify_update_msg]

      # all titles - update deadlines
      @deadline = from_json[:deadline]
      @grace_period = from_json[:grace_period]
      @grace_subj = from_json[:grace_subj]
      @grace_msg = from_json[:grace_msg]

      # all titles - General Jamf Patch Mgmt
      @jss_id = from_json[:jss_id]
      @jss_name_id = from_json[:jss_name_id]

      # all titles - D3 housekeeping
      @added_date = Time.parse(from_json[:added_date]) if from_json[:added_date]
      @added_by = from_json[:added_by]
      @last_modified = Time.parse(from_json[:last_modified]) if from_json[:last_modified]
      @modified_by = from_json[:modified_by]
      @latest_version = from_json[:latest_version]
      @released_version = from_json[:released_version]

      # all titles - changelog
      @changes = from_json[:changes]
    end

  end # class title

end # modle D3
