# Accessing the Xolo Server via HTTPS

While `xadm` is the preferred way to interact with the Xolo server, all that interaction is done via an HTTPS API, by exchanging JSON data with specific endpoints on the server. 

There may be times when you want to access the server using those endpoints yourself, rather than using `xadm`, for example, on a Continuous Integration node where you don't have ruby installed, and can't use `xadm`.

While doing so is not explicitly supported, this API documentation should help you do that if needed.

Since you'll be replicating some of what `xadm` does, feel free to look at its executable, and everything in `lib/xolo/admin`, to see how it does its thing.

This documentation is preliminary and may never be fully complete.

- [API Errors](errors.md)
- [General Purpose Endpoints](general.md)
  - [GET /ping](general.md#get_ping)
    Check server availability
  - [GET /streamed_progress](general.md#get_streamed_progress)
    Stream the progress of a long-running task in real time
- [Authentication Endpoints](authentication.md)
  - [POST /auth/login](authentication.md#post_auth_login)
    Authenticate to the Xolo server and acquire a session cookie
  - [POST /auth/logout](authentication.md#post_auth_logout)
    Log out the currently authenticated admin, and invalidate the session
  - [GET /auth/release_to_all_allowed](authentication.md#get_release_to_all_allowed)
    Check if the current admin is allowed to set a titles release groups to 'all'
- [Jamf Pro Endpoints](jamf_pro.md)
  - [GET /jamf/package-names](jamf_pro.md#get_jamf_package_names)
    List all Package Names known to Jamf Pro
  - [GET /jamf/computer-group-names](jamf_pro.md#get_jamf_computer_group_names)
    List all Computer Group Names known to Jamf Pro
  - [GET /jamf/category-names](jamf_pro.md#get_jamf_category_names)
    List all Category Names known to Jamf Pro
- [Title Editor Endpoints](title_editor.md)
  - [GET /title-editor/titles](title_editor.md#get_title_editor_titles)
    List all titles known to the title editor
- [Xolo Title Endpoints](titles.md)
  - [GET /titles](titles.md#get_titles)
    List all title objects known to xolo
  - [POST /titles](titles.md#post_titles)
    Create a title object
  - [GET /titles/{title}](titles.md#get_title)
    Fetch a title object
  - [PUT /titles/{title}](titles.md#put_title)
    Update a title object
  - [DELETE /titles/{title}](titles.md#delete_title)
    Delete a title object and all its versions
  - [POST /titles/{title}/ssvc-icon](titles.md#upload_ssvc_icon)
    Upload a Self-Service icon for a title
  - [GET /titles/{title}/frozen](titles.md#frozen_computers)
    List members of the 'frozen' group for a title
  - [PUT /titles/{title}/freeze](titles.md#freeze_computers)
    Add one or more computers to the 'frozen' group for a title
  - [PUT /titles/{title}/thaw](titles.md#thaw_computers)
    Remove one or more computers from the 'frozen' group for a title
  - [GET /titles/{title}/patch_report](titles.md#patch_report)
    Return info about all computers with a given title installe
  - [GET /titles/{title}/urls](titles.md#urls)
    Get URLs for all the Title Editor and Jamf WebApp pages related to a title
  - [GET /titles/{title}/changelog](titles.md#changelog)
    Change log for a title and all its versions
- [Xolo Version Endpoints](versions.md)
  - [GET /titles/{title}/versions](versions.md#get_versions)
    List all version objects belonging to a title
  - [POST /titles/{title}/versions](versions.md#post_versions)
    Create a version object in a title
  - [GET /titles/{title}/versions/{version}](versions.md#get_version)
    Fetch a version of a title
  - [PUT /titles/{title}/versions/{version}](versions.md#put_version)
    Update a version object
  - [PATCH /titles/{title}/release/{version}](versions.md#release_version)
    Release a version of a title
  - [DELETE /titles/{title}/versions/{version}](versions.md#delete_version)
    Delete a version of a title
  - [POST /titles/{title}/versions/{version}/pkg](versions.md#upload_pkg)
    Upload a .pkg file for a version
  - [GET /titles/{title}/versions/{version}/patch_report](versions.md#patch_report)
    Return info about all computers with a given version of a title installed
  - [GET /titles/{title}/versions/{version}/urls](versions.md#urls)
    Get URLs for all the Title Editor and Jamf WebApp pages related to a version
- [Server Maintenance Endpoints](maintenance.md)
  - [GET /maint/state](maintenance.md#get_maint_state)
    Get server state details
  - [POST /maint/cleanup](maintenance.md#post_maint_cleanup)
    Manually run the server's cleanup process
  - [POST /maint/update-client-data](maintenance.md#post_maint_update_client_data)
    Manually update the client-data pkg
  - [POST /maint/rotate-logs](maintenance.md#post_maint_rotate_logs)
    Manually rotate the server logs
  - [POST /maint/set-log-level](maintenance.md#post_maint_set_log_level)
    Set the server log level
  - [POST /maint/shutdown-server](maintenance.md#post_maint_shutdown_server)
    Shutdown or restart the server
- Xolo Title and Version Object Schemas
  - [Title Object Schema](title-schema.md) 
  - [Version Object Schema](version-schema.md)