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

  # To find the id of an existing icon:
  #   - go to any self-service page in the Jamf UI
  #   - Edit
  #   - Click the 'select existing icon' button in the icon section
  #   - right-click/ctrl-click on the icon you want
  #   - Copy Image Location/Link/Address
  #   - Click Cancel to exit icon select, and then click cancel agin to exit editing
  #   - Paste somewhere and you'll see a URL like this  https://casper.pixar.com:8443/icon?id=21936
  #   - the icon ID is at the end
  #
  # pol = JSS::Policy.fetch 'chrisltest-pol'
  # pol.icon = '/Users/chrisl/Desktop/teddy_cool-512.png'
  #  # ^^ Uploads and takes effect immediately
  #
  # pol.icon = 21936
  #  # ^^ requres pol.save
  # pol.save

  # the admin app
  class AdminApp

    DFT_DEADLINE = 0
    DFT_GRACE_PERIOD = 15
    DFT_GRACE_PERIOD_WARNING_SUBJ = 'Important'.freeze
    DFT_GRACE_PERIOD_WARNING_MSG = '$APP_NAMES will quit in $DELAY_MINUTES minutes so that $SOFTWARE_TITLE can be updated. Save anything you are working on and quit the app(s).'.freeze

    REQUIRED_TITLE_OPTS = %i[
      description
      publisher
    ].freeze

    TITLE_EXT_BANNER = D3.squiggilize_heredoc <<-ENDBANNER
      Working with titles in d3:
      ------------------
      Add a new title:
        d3admin [global opts] add-title <title> [title opts]

        <title> must not already exist in d3, and may not contain whitespace.

      Edit a title:
        d3admin [global opts] edit-title <title> [title opts]

      Delete a title:
        d3admin [global opts] delete-title <title>

      Add an Extension Attribute to a title:
        d3admin [global opts] add-ea <title> --ext-attr <path>

      Delete an Extension Attribute from a title:
        d3admin [global opts] delete-ea <title> --ext-attr <eaname>

      Requirements for adding titles
      ------------------
      All titles:
      - A reasonable description, for documentation purposes.
        The description must be more than 30 characters long, or contain an
        http(s) URL. The purpose is to require useful information for other
        admins, including future you. A title 'FooBar' with the description
        'Installs FooBar.app' is less than useful. Please describe what the thing
        is or does, and where or who it came from.

      Titles hosted by d3 must have:
      - at least one 'installed' criterion, see below.
      - a publisher, also for documentation purposes.

      Titles hosted outside of d3 must have:
      - the name of the Patch Source defined in Jamf Pro which hosts the title.

      Extension Attributes
      ------------------
      Each title can include one or more Extension Attributes to collect non-
      standard values from a computer for use in the installed- and
      eligibility-criteria of the title and its versions. (see below)
      These are similar to regular script-based computer Extension
      Attributes in Jamf Pro, but are limited to use with the title & its
      versions.

      The values from these Extension Attribute scripts are interpreted as strings,
      not integers or dates. As with regular script-based Computer Extension
      Attributes, they must return a '<result>value</result>' string to standard
      output.

      To add an Extension Attribute to a title, write the script and save it
      into a local file. The name of the file (with spaces removed and
      lowercase letters) becomes the name of the Extension Attribute, and
      cannot already exist in Jamf Pro, as a regular computer, or patch title
      Extension Attribute.

      Pass the path to that script as the value of the --ext-attr option with
      the 'add-ea' action.

      A Jamf Pro administrator must approve the title's Extension Attributes
      manually before the title can become active. This security measure gives
      the admin a chance to examine the script before it starts running on
      client computers.

      Installed-Criteria
      ------------------
      These criteria, when all true, indicate that a computer has some version
      of the title installed. They are built using the same fields and
      operators as 'Advanced Searches' and 'Smart Groups' in Jamf Pro.

      When specifying a criterion, provide either:
        1) a string with 4 or 5 comma-separated items defining the criterion.
        2) a path to a local application bundle (e.g. /Applications/SomeApp.app)

      *** Manually defining criteria
      The items in a criterion definition are, in order:
        and/or, type, fieldname, operator, value

      The first item may be 'and', 'or', or omitted, defaulting to 'and'.
      It is ignored for the first criterion.

      'type' is either:

         'recon' meaning the fieldname is one of those collected into Jamf by a
                 regular 'recon', including normal Computer Extension Attributes

         'ea' meaning the fieldname is one of the Extension Attribute names
              defined for this title, see above.

      'operator' is one of the valid comparison operators as used in Jamf Pro
      Advanced Searches and Smart Groups. e.g. 'is', 'is not', 'greater than'
      'like', 'matches regex', and so on.

      Examples:
        --criterion 'recon, Application Bundle ID, is, com.mycompany.myapp'
        --criterion 'or, ea, ext-attr-name, is not, some value'

      *** Automatically defining criteria for an application
      When given an app path, the app's Info.plist is used to generate a single
      criterion like this:

        'or, recon, Application Bundle ID, is, com.somecompany.someapp'

      This uses the 'Application Bundle ID' value, already collected by Jamf
      Pro during recons, to recognize that the title is installed. For most
      titles that install applications, this is sufficient.

      Expiration
      ------------------
      If you are using d3's expiration feature, use the --expiration option to
      specificy how many days of non-use before a title is uninstalled. Setting
      --expiration to zero means 'do not expire'

      When expiration is >0 you must also specify at least one Application
      Bundle ID with the --expiration-bundle option. This is the bundle id of an
      app that must come to the foreground to be considered 'use'. You can
      provide either an explicit bundle id, e.g. 'com.mycompany.myapp', or a
      path to a locally install .app and the bundle id will be read from the
      app's Info.plist. Anything containing a '/' is considered a path.

      If you specify more than one --expiration-bundle, any one of them coming
      to the foreground is considered 'use' and will prevent uninstallation.
      This is useful for titles that install more then one app.

      Self Service
      ------------------
      The title's Self Service options are applied to the initial-install and
      patch policies for the title. If specific versions need different settings,
      you should adjust them in the Jamf Pro web interface after the policies
      are created.

      Patch/Update Deadlines
      ------------------
      For machines with the title installed, newly released versions can be
      given a 'deadline' for updating - a number of days after with the update
      will be installed regardless of the user's wishes. This will cause any
      killapps for the version to be quit, and if needed the machine will be
      rebooted after the installation.

      To specify a deadline for the applying updates to the title, set
      --deadline to the number of days for the deadline, zero means there is no
      deadline.

      When a deadline is set, and that time arrives, the user is given a warning
      with a 'grace period' - the number of minutes before the killapps are quit
      and the upgrade begins. The default grace period is #{DFT_GRACE_PERIOD} minutes.
      This can be changed with --grace, but must be greater than zero.

      The default warning message has the subject '#{DFT_GRACE_PERIOD_WARNING_SUBJ}'
      and the message text:

        #{DFT_GRACE_PERIOD_WARNING_MSG}

      These can be changed with --grace-subj and --grace-msg. In the message,
      you can use placeholders for the list of killapps ($APP_NAMES), the grace
      period ($DELAY_MINUTES) and the title's display name ($SOFTWARE_TITLE)
    ENDBANNER

    TITLE_BANNER = D3.squiggilize_heredoc <<-ENDBANNER
      Options for d3 titles
      ------------------
    ENDBANNER

    TITLE_END_BANNER = D3.squiggilize_heredoc <<-ENDBANNER

     The following options can be given multiple times:
       --pilot-group, -auto-group, --excluded-group, --expiration-bundle,
       --criterion, --show-in-category, --feature-in-category

     Note: deleting a hosted title deletes all of its versions as well.'

   ENDBANNER

    def parse_title_opts
      show_ext = @global_opts.ext ? TITLE_EXT_BANNER : ''
      opts =
        Optimist.options do
          banner TITLE_BANNER
          # If we don't manually put this here, optimist will
          # put it below all banners.
          opt :help, 'Show this help', short: '-h'

          banner "\nTitles hosted outside d3"
          opt :patch_source, "The name of the non-d3 Patch Source hosting this title. The target must be the 'nameid' of the title on the source", short: '-P', type: :string
          opt :autopkg_recipe, 'Path to a recipe file for AutoPkg to use when a new version is available', short: :none, type: :string

          banner "\nTitles hosted by d3"
          opt :criterion, 'Path to .app bundle, or definition string. Appended to the criteria indicating the title is installed', short: '-I', type: :string
          opt :clear_criteria, 'Remove all installed criteria, At least one must be re-added with -I', short: :none
          opt :publisher, 'The publisher of the title', short: '-p', type: :string
          opt :ext_attr, "When action is 'add-ea', path to file containing ext. attrib. script. When 'delete-ea', the name of the ext. attrib. to delete.", short: '-E', type: :string

          banner "\nAll titles:"
          opt :description, 'Info about what is installed by this title', short: '-d', type: :string
          opt :category, 'Primary Jamf category for the title', short: '-c', type: :string
          opt :pilot_group, 'Make unreleased versions available to group members', short: '-t', type: :string
          opt :clear_pilot_groups, 'Remove previously defined pilot groups', short: '-T', type: :string
          opt :auto_group, 'Auto-install on all group members', short: '-a', type: :string, multi: true
          opt :clear_auto_groups, 'Remove all defined auto-groups', short: '-g'
          opt :standard, 'Auto-install on all non-excluded Macs, also clears auto-groups', short: '-S'
          opt :excluded_group, 'Computer group that cannot see this title', short: '-e', type: :string, multi: true
          opt :clear_excluded_groups, 'Remove all defined excluded-groups', short: '-G'
          opt :expiration, 'Auto-uninstall if unused for <days>, 0=dont expire', short: '-X', default: 0
          opt :expiration_bundle, 'App Bundle id that prevents expiration, or path to app', short: '-B', type: :string, multi: true

          banner "\nSelf Service:"
          opt :in_selfsvc, 'Make this title available in Self Service', short: '-s'
          opt :display_name, 'A more human-friendly name for Self Svc', short: '-N', type: :string
          opt :icon, 'Path to image or ID of existing icon for Self Svc', short: '-i', type: :string
          opt :notify, "Send notifications about this title, one of: 'none', 'sscv', 'nc' or 'both'", short: '-n', type: :string
          opt :resend, 'Re-notify all in-scope clients when changing Self Svc settings', short: :none

          # Initial Installs
          opt :feature, 'Feature this title in Self Svc main page', short: '-f'
          opt :show_in_category, 'Show in this Self Svc category', short: '-C', type: :string, multi: true
          opt :feature_in_category, 'Feature in the Self Svc category page', short: '-F', type: :string, multi: true
          opt :install_subj, 'Notification subject for initial installs', type: :string, short: :none
          opt :install_msg, 'Notification message for initial installs', type: :string, short: :none

          # Update installs
          opt :update_subj, 'Notification subject for update installs', type: :string, short: :none
          opt :update_msg, 'Notification message for update installs', type: :string, short: :none

          banner "\nUpdate Deadlines:"
          opt :deadline, 'Force update after this many days, killapps are quit, reboot if needed. 0 = no deadline', type: :integer, short: :none
          opt :grace, 'Give user this many minutes warning before quitting killapps, installing, rebooting if needed', type: :integer, short: :none
          opt :grace_subj, 'Subject of grace period warning message', type: :string, short: :none
          opt :grace_msg, 'Text of grace period warning message', type: :string, short: :none

          banner TITLE_END_BANNER
          banner show_ext
        end # Optimist.options do
      opts
    end # parse_title_opts

  end # class

end # module Xolo
