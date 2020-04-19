# Change History

## v3.0.20 - 2018-06-27
- Added: validate that a pkg is available via cloud before trying to install it that way
- Change: better backtrace logging
- Change: better error reporting when client passwd retrieval fails
- Fix: bug preventing puppies to install from the puppy queue

## v3.0.19 - 2018-03-31
- Added: signing identity and signing prefs to d3admin add, when building .pkgs
- Added: A default description editer (e.g. vi, emacs, pico) can be saved in admin prefs
- Fix: return nil when asked for current foreground application on client, and there is none.

## v3.0.18 - 2017-12-01
- Change: D3::Client.install: freeze prev. installed rcpts when 'freeze on install' requested.

## v3.0.17 - 2017-07-14
- Fix: D3::Package.upload_master_file, call #update after #super

## v3.0.16 - 2017-04-10
- Update: Max DB schema version bumped for 9.98 and 9.99

## v3.0.15 - 2017-02-28
- Bugfix: now correctly finds the most recent timestamp for an expiration path coming to the foreground

## v3.0.14 - 2016-12-08

- Bugfix: Stored receipts with the singular 'prohibiting_process' are now handled and updated to the plural 'prohibiting_processes'

## v3.0.13 - 2016-12-07

- Change: Updated CHANGES.md
- Change: Updated depot3.gemspec to require ruby-jss v0.6.6

## v3.0.12 - 2016-12-07

- Change: Packages can how have multiple 'prohibiting proceses', which are entered as a comma-separated string of process names. If any one of them is running at install or uninstall, an error is raised. Use --force to override.


## v3.0.11 - 2016-08-10

- Change: Eliminate DEFAULT_CPU_TYPE constant in favor of DEFAULT_PROCESSOR
- Fix: Prevent debug logging before it's asked for
- Change: added 'forget' action to d3, removes local receipt without attempting uninstall
- Fix: Client.update_receipts is more efficient now, only updating a rcpt once per run if needed
- Change: Client.sync now does "clean_missing_receipts" - after doing updates,to remove rcpts that are missing from d3
- Change: github issue #25 expiration path is now 'expiration paths' and can take a comma-separated list of paths. Any one of them coming to the foreground counts as 'being used' and will prevent expiration of the package. This is useful for single packages that install multiple apps, such as Microsoft Office.

## v3.0.10 - 2016-07-25 (unreleased)

- Fix: github issue #14 Don't crash when there's no rcpt file.
- Fix: github issue #21 d3: ArgumentError: Unknown d3 action: list_queue
- Change: remove hard-coded client timeout, use whatever is in ruby-jss.conf
- Fix: github issue #13 when adding pkgs with new version, revision resets to 1 by default.
- Fix: github issue #12allow 'n' or 'none' to unset expiration path
- Added: method D3::Admin::Auth.connected?
- Fix: no attempt to write log if it isn't writable to the user
- Change: bump max DB schema version to 9.93
- Change: remove 2-line log entries
- Change: d3admin: default to deleting unused scripts whe deleting packages
- Fix: d3 & d3admin: don't check the TTY unless there is one

## v3.0.9 - 2016-04-11

- d3: better text feedback during manual installs.
- Package.all_filenames: limit list to d3 packages, not all JSS packages.
- Client::Receript.add\_receipt: log "replaced" only when really replacing.
- d3helper: clean up rcpt import, add pkg ids, admin name.
- README: better contact info
- lots of comment changes for YARD parsing fix
- Package::Validate.check\_for\_exlusions: bugfix
- Added D3::DEBUG_FILE support for d3, d3admin, & d3helper. Used getting debug logging/output when d3 command is embedded in other tools. If the file /tmp/d3debug-on exists, it's the same using the --debug option
- d3: actions that don't need server connections can be done witout root: list-installed, list-manual, list-pilot, list-frozen, list-queue

## v3.0.8 - 2016-04-01

- Fix: pre- and post-install script failures no longer cause fatal exceptions, halting sync. Instead the error is reported, the package skipped, and the sync continues.

## v3.0.7 - 2016-04-01

Initial open source release

## v3.0.6 - 2016-03-28

Pixar internal release of v3.
