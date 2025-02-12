# Title JSON Schema

Title data in Xolo is exchanged and stored using this JSON Object. 

When reading title data from, or sending title data to, the Xolo server, this structure represents a title.

Depending on the usage, not all keys will be present. 

For example, the read-only values maintained by the server (e.g. 'created_by') are never sent to the server whe POSTing or PUTting. When GETting a titles, the versions will not be included, and must be fetched separately. 

This example shows all possible keys used in any context.

TODO: Document the different contexts and which keys are used in each.

```
{
  "title": "xolotest",
  "display_name": "Xolo Testing",
  "description": "A simple app for testing package/patch deployment with Xolo.",
  "publisher": "Pixar Animation Studios",
  "app_name": "XoloTest.app",
  "app_bundle_id": "com.pixar.xolotest",
  "version_script": null,
  "release_groups": [
    "Dogcows Macs - Workstations"
  ],
  "excluded_groups": [
    "chrisltest",
    "func-avid",
    "func-protools"
  ],
  "uninstall_script": null,
  "uninstall_ids": [
    "xom.pixar.xolotest",
    "com.pixar.xolotest.extras"
  ],
  "expiration": 45,
  "expire_paths": [
    "/tmp/foochrisl",
    "/tmp/foochrisl2"
  ],
  "self_service": true,
  "self_service_category": "testing",
  "self_service_icon": "uploaded",
  "contact_email": "chrisl@pixar.com",
  "created_by": "chrisl",
  "creation_date": "2024-12-02 14:05:41 -0800",
  "modified_by": "chrisl",
  "modification_date": "2024-12-02 16:15:07 -0800",
  "version_order": [
    "1.0.0",
    "0.0.25",
    "0.0.12",
    "0.0.5"
  ],
  "released_version": "0.0.12",
  "ted_id_number": 153,
  "ssvc_icon_id": null,
  "versions": [
    (see Version JSON Schema)
  ]
}
```