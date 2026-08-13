# Xolo Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## \[2.2.0] Unreleased

### Added

  - Titles can now take the `--self-service-updates` boolean option. This means that initial installs of a title via a Self Service Policy (the `--self-service` option) are completely independent from updates pushed out via Patch Policies in Self Service Updates.
  
    Here is the help output for the new option:
    
    ```
    Make versions available in Self Service for updates. This setting is independent of the `--self-service` setting for initial installs. Unlike that setting, this can be set when the release-group is 'all'.

    By default this is false, Patch Policies for versions will be set to 'Install Automatically'.

    If set to true, Patch Policies for versions will be set to 'Make Available in Self Service' and the version will appear in the Updates section when available. The update won't happen until the user clicks a button, or the 7-day deadline passes. Notifications will be displayed daily.

    When installing automatically, or the deadline passes, the update will happen at the checkin after the next recon. If the version has any KillApps, the user will be prompted to quit them, with a grace period of 15 minutes before the update starts.

    Any Self Service icon uploaded for the title will be used for its versions. If needed, upload one for the title with 'xadm edit-title `--self-service-icon /path/to/image/file'` (the title itself doesn't need to be in Self Service)

    To explicitly set this to false, use --no-self-service-updates.
    ```

  - Titles can now take the `--target-groups` option.
    
    Target groups are literally the opposite of `--excluded-groups`. 
    
    Computers NOT in the target groups are not able to see the title or its versions using Xolo. This is useful when you want to restrict the ability to install or update a title to only a small set of computers. Previously you would have to create a 'large' Jamf group of computers NOT allowed to see the title and use that as an excluded-group. 

    This is implemented by maintaining a smart computer group that contains computers NOT in the target-groups, and then using that smart-group in the exclusions for all scopes releated to the title. Basically it's a way to use computer-groups as scope-limitations, which Jamf Pro doesn't do directly.

    __IMPORTANT__:  `target-groups` are very different from `release-groups` or `pilot-groups`.  Release- and pilot-groups define computers that will _automatically_ get installs and updates, and when that will happen.  Target- and excluded-groups define computers that can even see that the title exists.  Targets and exclusions win over everything else.


  - Titles can now take the `--auto-release-delay <days>` option, but only if the title is subscribed and uses an AutoPkg recipe.
    
    This allows you to set a pilot-period of some number of days (including zero) for new versions that appear automatically via subscriptions and autopkg to remain in pilot. After that period, they are automatically released during the server's nightly maintenance tasks. During the pilot period, piloting can happen automatically via pilot-groups, or manually by installing the version on test machines.

    Use this option with caution! For many titles, like browswers, you probably want them to be auto-released quickly, to get the latest security changes. But every title is different and things like how it's used in your environment, and the source of the packages, may increase the risks involved in auto-release .

    Titles that are managed, or do not use AutoPkg, cannot use this. Releasing their versions from pilot requires someone to use `xadm release <title> <version>`
    
### Changed
  
  - If you try to release a version before Jamf Pro has seen it in the Title Editor, you'll get a better error message early in the process. Before it would just fail when it tried to access the not-yet-existent Patch Policy.

  - Progress streaming from the server to xadm will no longer die during long-lasting steps. A line of dots will appear, one dot for every 10 seconds of waiting for actual progress data.

### Added
  - The `xadm list-titles` command now takes 2 new CLI options
    - `-i, --self-service          Show only titles that are available for initial instalation via Self Service.`
    - `-u, --self-service-updates  Show only titles that are available for updates via Self Service.`

## \[2.1.0] 2026-08-05

### Added
  - The `xadm list-titles` command now takes 4 new CLI options
    - `-s, --subscribed  Show only 'subscribed' titles.`
    - `-m, --managed     Show only 'managed' titles.`
    - `-a, --autopkg     Show only titles configured for AutoPkg.`
    - `-p, --pilots      Show only titles with pending pilot (un-released) versions.`
      
      These options can be combined and are useful for finding titles and versions that need attention, such as new pilot versions automatically created by subscription and autopkg, but haven't been released yet.

  - The `xadm list-versions <title>` command now indicates if a version doesn't yet have a .pkg file uploaded, by marking the end of the line with `**`

### Changed
  - The `xolo` client tool now (again) accepts the original syntax of `xolo install title version` without an `=` between the title and version, as long as you're only installing that one item. Using an `=` will still work too.  If you want to install multiple items with specific versions, you must use the `=`.

  ```
  # installs version 1.2.3 of title foobar
  % sudo xolo install foobar 1.2.3  

  # the same: installs version 1.2.3 of title foobar
  % sudo xolo install foobar=1.2.3  

  # installs the currently released versions titles foobar and barbaz
  % sudo xolo install foobar barbaz  

  # installs version 1.2.3 of title foobar, current release of title   
  # barbaz and version "45.2 (413)" of title zip
  % sudo xolo install foobar=1.2.3 barbaz 'zip=45.2 (413)'
  
  # this will fail as it will interpret '1.2.3' and 
  # '45.2 (413)' as titles
  % sudo xolo install foobar 1.2.3 barbaz zip '45.2 (413)'
  ```

## \[2.0.3] 2026-07-25

### Fixed 
  - Changing `patch_unknown` with `xadm edit-version` now actually works
  - `--pkg-to-upload` no longer requires an absolute path
  - Errors for unknown vars in error messages
  - The client-data package is updated in more appropriate places
  - Removed problematic/unneeded shell-escapes
  - Self Service description and display name are now updated correctly with `xadm edit-title`
  - Remove method `delete_lingering_policies_for_title` - can delete things from other titles!
  - Run update_client_data when new versions come from subscriptions
  - Fix erroneous alert about no `--pkg-to-upload`
  - Fix handling of versions with spaces and non-alphanumeric characters. (We're looking at you, Zoom!)

### Changed
  - When a title is in Self Service, the patch policies are also deployed via Self Service
    - TODO: allow setting of various SSvc/User interaction parameters in patch policies via `xadm`.
  - Title Info only shows title_id and patch_source in human output if title is subscribed
  - Ensure no pkg files in the `autopkg_directory` before running an autopkg recipe

### Added
  - The `xolo` client CLI tool now takes a `--test` option. 
    
    If your environment has a second xolo server configured as a test server, using the same Jamf Pro and Title Editor as your production xolo server, then this option makes `xolo` use the data-file, policies, patch policies, and other xolo objects maintained by the test server, ignoring those maintained by the production server. 
    
    Setting the `XOLO_TEST_MODE` environment variable will do the same thing.

## \[2.0.2] 2026-05-16

### Fixed 

  - More bugfixes, including Self Service management.

## \[2.0.1] Internal Release

### Fixed 

  - Many bugfixes and small improvements including: 
    - Validation and Interactive/walkthru choices for managed vs subscribed titles.
    - Handling of re-uploaded pkgs

## \[2.0.0] Internal Release

### Added

  - Subscribed Titles

    Normal Xolo titles are "managed" - All aspects of the title are managed via `xadm` including the addition of new verions. Such titles are maintained via the Title Editor patch source.

    Xolo can now also subscribe to titles maintained by other Patch Sources (e.g. the Jamf Built-In) or those maintained in the Title Editor outside of Xolo. For these titles you cannot specify `--display-name`, `--publisher`, `--app-name` & `--app-bundle-id` or `--version-script`, those will be set by the patch-source. Other values for the title are set as usual. New versions appear via the subscription, and the xoloserver handles them via Webhook Events. 

    To subscribe to a title,specify `--subscribed` when you use `xadm add-title`. This means you must provide a valid `--patch-source` and `--title-id`. See the new `list-available` xadm command, below.

    Titles cannot be changed between subscribed and managed once created. To do so requires deleting the title (and all its versions) and re-adding it.

    Once the title is added, xoloserver will recieve [PatchSoftwareTitleUpdated webhook events](https://developer.jamf.com/developer-guide/docs/webhooks#patchsoftwaretitleupdated) from Jamf Pro when new versions become available. The xoloserver automatically creates a new xolo version (the equivalent of `xadm add-version`) and will either notify someone to upload a .pkg for it, or, if the server and title are configured for it, use autopkg to acquire and upload the .pkg.

    NOTE: Install Policies and Patch Policies will fail until a .pkg is uploaded.

    NOTE 2: If a subscribed title uses an Extension Attribute ('version-script') it must be manually accepted in the Jamf Pro web UI. Xolo cannot auto-accept extension attributes it does not manage. Patch Policies and reporting will not work until it has been accepted.

  - New xadm command `list-available`
  
    This outputs a list of all titles available for subscription on all defined Jamf Patch Sources.  Titles already activated/subscribed in Jamf Patch (including all managed or subscribed Xolo titles) will not appear. This is useful/needed when adding a subscribed title, to identify the correct patch source and title id.

  - AutoPkg support

    Titles can be configured to acquire the .pkg files for new versions via [AutoPkg](https://github.com/autopkg/autopkg)

    When a new version is added to a title, either via `xadm add-version` or a webhook event from a subscribed title (see above), the xoloserver can run a specified AutoPkg recipe to get the latest installer package.

    This requires installing, configuring, and maintaining `autopkg` on the xoloserver machine separately from xoloserver itself, and setting the `autopkg_executable` setting (a path) and a non-root `autopkg_user` (a username) in the server config. The xoloserver will merely execute a given recipe, and look for the resulting .pkg file. 

    To use autopkg with a title, just specify `--autopkg-recipe recipe.name` and `--autopkg-dir /path/to/dir/with/autopkg-output/` with xadm's `add-title` or `edit-title` commands.

    If those value are set, when a new version is added to xolo, the server will execute `autopkg run recipe.name` and when complete, it will use the newest pkg it finds in `/path/to/dir/with/autopkg-output/` which it will upload to the Jamf Distribution points as with any other pkg.

    IMPORTANT: When running autopkg recipes, the `-k FAIL_RECIPES_WITHOUT_TRUST_INFO=yes` option is always used. This means that all such recipies MUST have an 'override' created, even if that override doesn't change anything. For details see [AutoPkg and recipe parent trust info](https://github.com/autopkg/autopkg/wiki/AutoPkg-and-recipe-parent-trust-info)

    If autopkg is enabled on the server, .pkgs acquired that way are not signed by the xoloserver unless the `sign_autopkg_pkgs` config setting is true. __BE CAREFUL__ setting this, make sure you trust your autopkg recipes!

  - Patching Unknown Versions
    
    When adding or editing versions, you can now set the `--patch-unknown` option, which defaults to false. Setting this to true means that the patch policy for this version will install the .pkg onto Macs with 'unknown' versions (see below). 
    
    This can cause problems if that unknown version is actually newer than this version, e.g. a beta or pre-release version, or when the app has a 'self-update' mechanism that installs newer versions outside of Jamf Patch before it is aware of them.

    But sometimes it may be desirable to have all unknown versions updated to this version, e.g. when the title is a helper app that is not regularly updated, or when the title is being newly managed by Xolo/Jamf Patch and you want to get all existing installations onto this version.

  - APIClient support for xoloserver connection to Jamf Pro

    In the server configration, set `jamf_use_api_client` to true, This will cause the value of `jamf_api_user` to be used as an API Client ID, and the value of `jamf_api_pw` to use used as the related secret.

    The API Client must have the same permissions, granted via one or more API Roles, that a service account would have, as listed in the [GitHub Wiki for Xolo](https://github.com/PixarAnimationStudios/xolo/wiki/Installing-xoloserver)

  - Automatic wrapping of component pkgs into distribution pkgs
    
    If the `create_distribution_pkgs` config is set to true on the xoloserver, it will examine each .pkg it recieves, via xadm upload, or autpkg. If the pkg is not a distribution pkg, it will be wrapped inside one, so that it can be deployed via MDM. The wrapper pkg will be signed based on the `sign_pkgs` and `sign_autopkg_pkgs` settings.


### Changed

  - Retaining Title Editor Version definitions.
    
    When you delete a version, but not the whole title, only the Jamf objects related to the version are deleted, as well as Xolo's awareness that the version exists. The Title Editor data for the version remains as long as the title exists.
    
    This is needed because if the version is deleted from the Title Editor, any Macs with that version installed will show up in patch reports with an 'unknown' version (if it isn't in the Title Editor, it is unknown to Jamf Patch).  This can prevent those macs from ever getting newer versions automatically, unless 'Update Unknown Versions' is set in the later patch policies - which by default is not.

    If you re-add the version, the Title Editor data for it is removed and re-added.
  
  - No more need for a duplicate 'normal' Extension Attribute when a managed title uses a version_script, or a subscribed title includes one.
    
    The 'normal' EA was used to create various smart groups for scoping, since the Patch EA is not available directly as a group criterion. However, there is a "Patch Title: _display_name_" criterion which can do the same thing. We now use that and the smart groups are much simpler, as is all code dealing with the EAs.

  - Installing multiple titles at once with `xolo install` and command-line syntax change.

    You can now install more than one title at a time with `xolo install title-1 title-2 ...`.
    
    __IMPORTANT SYNTAX CHANGE__: To avoid complex commandline parsing, we've changed how you indicate a specific version to install. If you want a version other than the current release, you have to connect the version to the title with `=`, for example `xolo install title-1=1.2.3 title-2 title-3=123.4.5`. This will install version 1.2.3 of title-1, the current release of title-2, and version 123.4.5 of title-3.


### Fixed
   
  - When using walkthru to add or edit a version's "Package to upload", you no longer get an error when dragging files in from the Finder with spaces in their paths.



### Removed

  - Xolo no longer supports bundle-style non-flat .pkg/.mpkg installers.
    
    The first version of Xolo would zip the bundle-directory and use the zip file - which I think Jamf still supports. This is no longer the case.
    
    Flat Packages have been around since macOS 10.5, and have been preferred for years. They are required for deployment via MDM. Until recently at least one major software company was still deplying bundle-style packages. Now that they are not, there's little reason for Xolo to support them, helping to simplify the code a bit.

## \[1.0.2] Internal Release

### Fixed
  - Setting KillApps in walkthru mode now shows a prompt for each line expecting input.
  - Now correctly differentiates `false` from `nil` values when updating a titles changelog.
 

## \[1.0.1] - 2025-10-02

### Added 
  - `xadm` now has a config option to not verify the server's SSL certificate, needed when the server uses a self-signed certificate.

### Changed
  - Enforce some serverside file permissions
  - Improved error messaging in xadm with unknown titles or versions

### Fixed
  - Gemspec paths
  - Configuration problems with the 'normal' Ext Attrib. in Jamf Pro.
  - Ensure auto-install policy is enabled when a version is released
  - When ever repairing a title in title editor also repair all patches, because the title repair causes them to be disabled, often by deleting their component critera, which disables the title itself.
  - Similarly, when repairing a patch in the title editor, be sure to re-enable the title itself, as it will become disabled when any change is made to a Patch.
  - Fix the use of 'all' when setting release-groups in xadm's interactive mode

## \[1.0.0] - 2025-09-28

Initial public release.

