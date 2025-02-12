# Accessing the Xolo Server via HTTPS

While `xadm` is the preferred way to interact with the Xolo server, all that interaction is done via an HTTPS API, by exchanging JSON data with specific endpoints on the server. 

There may be times when you want to access the server using those endpoints yourself, rather than using `xadm`, for example, on a Continuous Integration node where you don't have ruby installed, and can't use `xadm`.

While doing so is not explicitly supported, this API documentation should help you do that if needed.

Since you'll be replicating some of what `xadm` does, feel free to look at its executable, and everything in `lib/xolo/admin`, to see how it does its thing.

This documentation is preliminary and may never be fully complete.

- [API Errors](errors.md)
- [General Purpose Endpoints](general.md)
  - [GET /ping](general.md#get_ping)
  - [GET /streamed_progress](general.md#get_streamed_progress)
- [Authentication Endpoints](authentication.md)
  - [POST /auth/login](authentication.md#post_auth_login)
  - [POST /auth/logout](authentication.md#post_auth_logout)
  - [GET /auth/release_to_all_allowed](authentication.md#get_release_to_all_allowed)
- [Jamf Pro Endpoints](jamf_pro.md)
  - [GET /jamf/package-names](jamf_pro.md#get_jamf_package_names)
  - [GET /jamf/computer-group-names](jamf_pro.md#get_jamf_computer_group_names)
  - [GET /jamf/category-names](jamf_pro.md#get_jamf_category_names)
- [Title Editor Endpoints](title_editor.md)
  - [GET /title-editor/titles](title_editor.md#get_title_editor_titles)
- [Xolo Title Endpoints](titles.md)
  - [GET /titles](titles.md#get_titles)
  - [POST /titles](titles.md#post_titles)
  - [GET /titles/{title}](titles.md#get_title)
  - [PUT /titles/{title}](titles.md#put_title)
  - [DELETE /titles/{title}](titles.md#delete_title)
  - [POST /titles/{title}/ssvc-icon](titles.md#upload_ssvc_icon)
  - [GET /titles/{title}/frozen](titles.md#frozen_computers)
  - [PUT /titles/{title}/freeze](titles.md#freeze_computers)
  - [PUT /titles/{title}/thaw](titles.md#thaw_computers)
  - [GET /titles/{title}/patch_report](titles.md#patch_report)
  - [GET /titles/{title}/urls](titles.md#urls)
  - [GET /titles/{title}/changelog](titles.md#changelog)
- [Xolo Version Endpoints](versions.md)
  - [GET /titles/{title}/versions](versions.md#get_versions)
  - [POST /titles/{title}/versions](versions.md#post_versions)
  - [GET /titles/{title}/versions/{version}](versions.md#get_version)
  - [PUT /titles/{title}/versions/{version}](versions.md#put_version)
  - [PATCH /titles/{title}/release/{version}](versions.md#release_version)
  - [DELETE /titles/{title}/versions/{version}](versions.md#delete_version)
  - [POST /titles/{title}/versions/{version}/pkg](versions.md#upload_pkg)
  - [GET /titles/{title}/versions/{version}/patch_report](versions.md#patch_report)
  - [GET /titles/{title}/versions/{version}/urls](versions.md#urls)
- [Server Maintenance Endpoints](maintenance.md)
  - [GET /maint/state](maintenance.md#get_maint_state)
  - [POST /maint/cleanup](maintenance.md#post_maint_cleanup)
  - [POST /maint/update-client-data](maintenance.md#post_maint_update_client_data)
  - [POST /maint/rotate-logs](maintenance.md#post_maint_rotate_logs)
  - [POST /maint/set-log-level](maintenance.md#post_maint_set_log_level)
  - [POST /maint/shutdown-server](maintenance.md#post_maint_shutdown_server)
- Xolo Title and Version Object Schemas
  - [Title Object Schema](title-schema.md) 
  - [Version Object Schema](version-schema.md)