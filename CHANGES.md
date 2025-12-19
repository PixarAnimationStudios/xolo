# Xolo Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## \[2.0.0] Unreleased

## Added

  - Subscribed Titles

    Xolo can now handle titles that are maintained by other Patch Source (e.g. the Jamf Built-In) or by non-Xolo means via the Title Editor.

    When adding a title, you can specify it's `--type` as 'subscribed'. This means you must provide a valid `--patch-source` and `--title-id`  and you cannot provide `--display-name`, `--publisher`, `--app-name` & `--app-bundle-id` or `--version-script`, those will be set by the patch-source. Other values for the title are set as usual.

    Once the title is added, xoloserver will recieve [PatchSoftwareTitleUpdated webhook events](https://developer.jamf.com/developer-guide/docs/webhooks#patchsoftwaretitleupdated) from Jamf Pro. If the updated title is one of xolo's subscribed titles, xoloserver automatically creates a new version (the equivalent of `xadm add-version`) and will either notify someone to upload a .pkg for it, or, if the server and titled are configured for it, use autopkg to acquire and upload the .pkg.

    NOTE: Install Policies and Patch Policies will fail until a .pkg is uploaded.

  - New xadm command `list-available`. 
  
    This outputs a list of all titles available for subscription on all defined Jamf Patch Sources.  Titles already activated/subscribed in Jamf Patch (including all managed or subscribed Xolo titles) will not appear. This is useful/needed when adding a subscribed title, to identify the correct patch source and title id.

  - AutoPkg support.

    Titles can be configured to acquire the .pkg files for new versions via [AutoPkg](https://github.com/autopkg/autopkg)

    When a new version is added to a title, either via `xadm add-version` or a Subscribed title (see above), the xoloserver can run a specified AutoPkg recipe to get the desired installer package.

    This requires installing, configuring, and maintaining `autopkg` on the xoloserver machine separately from xolo itself. The xoloserver will only execute a recipe, and look for the resulting .pkg file.

  - Patching Unknown Versions
    
    When adding or editing versions, you can now set the `--patch-unknown` option, which defaults to false. Setting this to true means that the patch policy for this version will install the .pkg onto Macs with 'unknown' versions (see below). 
    
    This can cause problems if that unknown version is actually newer than this version, e.g. a beta or pre-release version, or when the app has a 'self-update' mechanism that installs newer versions outside of Jamf Patch before it is aware of them.

    But sometimes it may be desirable to have all unknown versions updated to this version, e.g. when the title is a helper app that is not regularly updated, or when the title is being newly managed by Xolo/Jamf Patch and you want to get all existing installations onto this version.

## Changed

  - Retaining Title Editor Version definitions.
    
    When you delete a version, but not the whole title, only the Jamf objects related to the version are deleted, as well as Xolo's awareness that the version exists. The Title Editor data for the version remains as long as the title exists.
    
    This is needed because if the version is deleted from the Title Editor, any macs with that version installed will show up in patch reports with an 'unknown' version (if it isn't in the Title Editor, it is unknown to Jamf Patch).  This can prevent those macs from ever getting newer versions automatically, unless 'Update Unknown Versions' is set in the later patch policies - which by default is not.


## \[1.0.2] Unreleased

### Fixed
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

