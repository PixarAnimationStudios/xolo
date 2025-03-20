# Version JSON Schema

Version data in Xolo is exchanged and stored using this JSON Object. 

When reading version data from, or sending version data to, the Xolo server, this structure represents a version of a title.

Depending on the usage, not all keys will be present. 

For example, the read-only values maintained by the server (e.g. 'created_by') are never sent to the server whe POSTing or PUTting. 

This example shows all possible keys used in any context.

TODO: Document the different contexts and which keys are used in each.

```
{
  "created_by": "chrisl",
  "creation_date": "2024-12-02 15:37:34 -0800",
  "deprecated_by": null,
  "deprecation_date": null,
  "dist_pkg": true,
  "jamf_pkg_file": "xolo-xolotest-1.0.0.pkg",
  "jamf_pkg_id": 11231,
  "jamf_pkg_name": "xolo-xolotest-1.0.0",
  "killapps": [
    "XoloTest.app;com.pixar.xolotest"
  ],
  "max_os": "23.1",
  "min_os": "10.6",
  "modification_date": "2024-12-02 15:38:20 -0800",
  "modified_by": "chrisl",
  "pilot_groups": [
    "chrisltest-smartgroup"
  ],
  "pkg_to_upload": "/Users/chrisl/git/xolo-titles/xolotest/xolotest-100.pkg",
  "publish_date": "2024-12-02 00:00:00 -0800",
  "reboot": false,
  "release_date": null,
  "released_by": null,
  "sha_512": "hex-string-goes-here",
  "skipped_by": null,
  "skipped_date": null,
  "standalone": true,
  "status": "pilot",
  "ted_id_number": 237,
  "title": "xolotest",
  "version": "1.0.0"
}
```