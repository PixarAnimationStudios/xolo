# Xolo Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## \[Unreleased]

## \[1.0.1] - 2025-10-02

### Added 
  - `xadm` now has a config option to not verify the server's SSL certificate, needed when the server uses a self-signed certificate.

### Changed
  - Enforce some serverside file permissions

### Fixed
  - Gemspec paths
  - Configuration problems with the 'normal' Ext Attrib. in Jamf Pro.
  - Ensure auto-install policy is enabled when a version is released
  - When ever repairing a title in title editor also repair all patches, because the title repair causes them to be disabled, often by deleting their component critera, which disables the title itself.
  - Similarly, when repairing a patch in the title editor, be sure to re-enable the title itself, as it will become disabled when any change is made to a Patch.
  - Allow use of 'all' when setting release-groups in xadm's interactive mode

## \[1.0.0] - 2025-09-28

Initial public release.

