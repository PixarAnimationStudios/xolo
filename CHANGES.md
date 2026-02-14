# Xolo Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## \[2.0.0] Unreleased

## Added

  - Subscribed Titles

    Normal Xolo titles are "managed" - All aspects of the title are managed via `xadm` including the addition of new verions. Such titles are maintained via the Title Editor patch source.

    Xolo can now also subscribe to titles maintained by other Patch Sources (e.g. the Jamf Built-In) or those maintained separately in the Title Editor. For these titles you cannot specify `--display-name`, `--publisher`, `--app-name` & `--app-bundle-id` or `--version-script`, those will be set by the patch-source. Other values for the title are set as usual. New versions appear via the subscription, and the xoloserver handles them via Webhook Events. 

    To subscribe to a title,specify `--subscribed` when you use `xadm add-title`. This means you must provide a valid `--patch-source` and `--title-id`. See the new `list-available` xadm command, below.

    Once the title is added, xoloserver will recieve [PatchSoftwareTitleUpdated webhook events](https://developer.jamf.com/developer-guide/docs/webhooks#patchsoftwaretitleupdated) from Jamf Pro when new versions become available. The xoloserver automatically creates a new xolo version (the equivalent of `xadm add-version`) and will either notify someone to upload a .pkg for it, or, if the server and titled are configured for it, use autopkg to acquire and upload the .pkg.

    NOTE: Install Policies and Patch Policies will fail until a .pkg is uploaded.

    NOTE 2: If a subscribed title uses an Extension Attribute ('version-script') it must be manually accepted in the Jamf Pro web UI. Xolo cannot auto-accept extension attributes it does not manage. Patch Policies and reporting will not work until it has been accepted.

  - New xadm command `list-available`. 
  
    This outputs a list of all titles available for subscription on all defined Jamf Patch Sources.  Titles already activated/subscribed in Jamf Patch (including all managed or subscribed Xolo titles) will not appear. This is useful/needed when adding a subscribed title, to identify the correct patch source and title id.

  - AutoPkg support.

    Titles can be configured to acquire the .pkg files for new versions via [AutoPkg](https://github.com/autopkg/autopkg)

    When a new version is added to a title, either via `xadm add-version` or a webhook event from a subscribed title (see above), the xoloserver can run a specified AutoPkg recipe to get the desired installer package.

    This requires installing, configuring, and maintaining `autopkg` on the xoloserver machine separately from xolo itself, and setting the `autopkg_executable` setting (a path) and a non-root `autopkg_user` (a username) in the server config. The xoloserver will merely execute a given recipe, and look for the resulting .pkg file. 

    To use autopkg with a title, just specify `--autopkg-recipe recipe.name` and `--autopkg-dir /path/to/dir/with/autopkg-output/` with xadm's `add-title` or `edit-title` commands.

    If those value are set, when a new version is added to xolo, the server will execute `autopkg run recipe.name` and when complete, it will use the newest pkg it finds in `/path/to/dir/with/autopkg-output/` which it will upload to the Jamf Distribution points as with any other pkg.

    IMPORTANT: When running autopkg recipes, the `-k FAIL_RECIPES_WITHOUT_TRUST_INFO=yes` option is always used. This means that all such recipies MUST have an 'override' created, even if that override doesn't change anything. For details see [AutoPkg and recipe parent trust info](https://github.com/autopkg/autopkg/wiki/AutoPkg-and-recipe-parent-trust-info)

  - Patching Unknown Versions
    
    When adding or editing versions, you can now set the `--patch-unknown` option, which defaults to false. Setting this to true means that the patch policy for this version will install the .pkg onto Macs with 'unknown' versions (see below). 
    
    This can cause problems if that unknown version is actually newer than this version, e.g. a beta or pre-release version, or when the app has a 'self-update' mechanism that installs newer versions outside of Jamf Patch before it is aware of them.

    But sometimes it may be desirable to have all unknown versions updated to this version, e.g. when the title is a helper app that is not regularly updated, or when the title is being newly managed by Xolo/Jamf Patch and you want to get all existing installations onto this version.

  - API Client support for xoloserver connection to Jamf Pro

    In the server configration, set `jamf_use_api_client` to true, This will cause the value of `jamf_api_user` to be used as an API Client ID, and the value of `jamf_api_pw` to use used as the related secret.

    The API Client must have the same permissions, granted via one or more API Roles, that a service account would have, as listed in the [GitHub Wiki for Xolo](https://github.com/PixarAnimationStudios/xolo/wiki/Installing-xoloserver)


## Changed

  - Retaining Title Editor Version definitions.
    
    When you delete a version, but not the whole title, only the Jamf objects related to the version are deleted, as well as Xolo's awareness that the version exists. The Title Editor data for the version remains as long as the title exists.
    
    This is needed because if the version is deleted from the Title Editor, any macs with that version installed will show up in patch reports with an 'unknown' version (if it isn't in the Title Editor, it is unknown to Jamf Patch).  This can prevent those macs from ever getting newer versions automatically, unless 'Update Unknown Versions' is set in the later patch policies - which by default is not.
  
  - No more need for a duplicate 'normal' Extension Attribute when a managed title uses a version_script, or a subscribed title includes one.
    
    The 'normal' EA was used to create various smart groups for scoping, since the Patch EA is not available directly as a group criterion. However, there is a "Patch Title: _display_name_" criterion which can do the same thing. We now use that and the smart groups are much simpler, as is all code dealing with the EAs.

## Fixed
   
  - When using walkthru to add or edit a version's "Package to upload", you no longer get an error when dragging files in from the Finder with spaces in their paths.
  - Setting KillApps in walkthru mode now shows a prompt for each line expecting input.
  - Now correctly differentiates `false` from `nil` values when updating a title's changelog.
 
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

