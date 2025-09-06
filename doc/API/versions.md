# Endpoints related to Xolo Versions

<!-- ------------------------- -->
<a id="get_default_min_os"></a>
## GET /default_min_os

#### Purpose
Learn the default value for the 'min_os' of versions.

While Xolo defines a hard-coded value, the server may be configured to use a different value. 

This endpoint is how you can get the value to be used, the server-defined one or the hard-coded one.

#### Notes
This endpoint does not require authentication.

#### Path Parameters
None

#### Request
Type: None

#### Response
Type: JSON Object with a single String value in 'min_os'<br/>
Schema:
```
{
  "min_os": "version"
}
```



<!-- ------------------------- -->
<a id="get_versions"></a>
## GET /titles/{title}/versions

#### Purpose
List all version objects belonging to a title

#### Path Parameters
`title` - the desired title

#### Request
Type: None

#### Response
Type: JSON Array of [Xolo Version Objects](version-schema.md)  
Schema:
```  
[
  {Version Object},
  ...
]
```

<!-- ------------------------- -->
<a id="post_versions"></a>
## POST /titles/{title}/versions

#### Purpose
Create a version object in a title

#### Path Parameters
`title` - the desired title

#### Request
Type: JSON Object  
Schema: [Xolo Version Object](version-schema.md)

#### Response
Type: JSON Object with stream path  
Schema:
```
  {
    "status": 'running',
    "progress_stream_url_path": "path/for/streaming/output"
  }
```

<!-- ------------------------- -->
<a id="get_version"></a>
## GET /titles/{title}/versions/{version}

#### Purpose
Fetch a version of a title

#### Path Parameters
`title` - the desired title  
`version` - the desired version

#### Request
Type: None

#### Response
Type: JSON Object  
Schema: [Xolo Version Object](version-schema.md)  


<!-- ------------------------- -->
<a id="put_version"></a>
## PUT /titles/{title}/versions/{version}

#### Purpose
Update a version object

#### Path Parameters
`title` - the desired title  
`version` - the desired version

#### Request
Type: JSON Object  
Schema: [Xolo Version Object](version-schema.md)  

#### Response
Type: JSON Object with stream path  
Schema:
```
  {
    "status": 'running',
    "progress_stream_url_path": "path/for/streaming/output"
  }
``` 

<!-- ------------------------- -->
<a id="release_version"></a>
## PATCH /titles/{title}/release/{version}

#### Purpose
Release a version of a title

#### Path Parameters
`title` - the desired title  
`version` - the desired version

#### Request
Type: none

#### Response
Type: JSON Object with stream path  
Schema:
```
  {
    "status": 'running',
    "progress_stream_url_path": "path/for/streaming/output"
  }
``` 

<!-- ------------------------- -->
<a id="repair_version"></a>
## POST /titles/{title}/versions/{version}/repair

#### Purpose
Repair the Title Editor and Jamf Pro objects for a version.

#### Path Parameters
`title` - the desired title  
`version` - the desired version

#### Request
Type: none

#### Response
Type: JSON Object with stream path
Schema:
```
{
  "status": 'running',
  "progress_stream_url_path": "path/for/streaming/output"
}
```


<!-- ------------------------- -->
<a id="delete_version"></a>
## DELETE /titles/{title}/versions/{version}

#### Purpose
Delete a version object from a title

#### Path Parameters
`title` - the desired title  
`version` - the desired version

#### Request
Type: none

#### Response
Type: JSON Object with stream path
Schema:
```
{
  "status": 'running',
  "progress_stream_url_path": "path/for/streaming/output"
}
```

<!-- ------------------------- -->
<a id="upload_pkg"></a>
## POST /titles/{title}/versions/{version}/pkg

#### Purpose
Upload the .pkg for a version

#### Path Parameters
`title` - the desired title  
`version` - the desired version

#### Request
Type: Multipart form with file upload

#### Response
Type: JSON Object  
Schema:
```
{
  "result": "uploaded"
}
```

<!-- ------------------------- -->
<a id="patch_report"></a>
## GET /titles/{title}/versions/{version}/patch_report

#### Purpose
Return info about all computers with a given version of a title installed

#### Path Parameters
`title` - the desired title  
`version` - the desired version

#### Request
Type: none

#### Response
Type: JSON Array  
Schema:
```
[
  JSON Object of computer data,
  ...
]
```

<!-- ------------------------- -->
<a id="urls"></a>
## GET /titles/{title}/versions/{versions}/urls

#### Purpose
URLs for all the Title Editor and Jamf WebApp pages related to a version

#### Notes
Keys of the response object will vary depending on the state of the title

#### Path Parameters
`title` - the desired title  
`version` - the desired version

#### Request
Type: none

#### Response
Type: JSON Object  
Schema:
```
{
  "ted_patch_url": "url",
  "jamf_auto_install_policy_url": "url",
  "jamf_manual_install_policy_url": "url",
  "jamf_patch_policy_url": "url",
  "jamf_package_url": "url"
}
```

<!-- ------------------------- -->
<a id="deploy">---</a>
## POST /titles/{title}/versions/{version}/deploy

#### Purpose
Deploy a version for installation on one or more computers or computer-groups

#### Notes
An MDM 'InstallEnterpriseApplication' command will be sent to the target computers to
install the version. If the version is already installed, it will be updated.
Computers in any excluded-groups for the target will be removed from the list of targets before
the MDM command is sent.

Computers can be specified by name, serial number, or Jamf ID. Groups can be specified by name or ID.

The package for the version must be a signed 'Product Archive', like those built with
'productbuild', not a 'component package', as is generated by 'pkgbuild'.
When you upload the .pkg to Xolo, it will automatically get a basic manifest needed for the
MDM command.

The response object contains three arrays of objects:
- removals: target computers or groups that were removed as targets, and the reason why
- queuedCommands: Machines that were sent the MDM command successfully, and the MDM Command UUID (may be useful for troubleshooting). 
  NOTE: Sending the MDM command doesn't mean that the install was successful - there's no way to know that other than on the computer itself.
- errors: Machines that did not get the MDM command successfully, and the reason why.

#### Path Parameters
`title` - the desired title  
`version` - the desired version

#### Request
Type: JSON Object  
Schema:
```
{
  "computers": ["computer identifier", ...],
  "groups": ["group identifier", ...]
}
```
#### Response
Type: JSON Object  
Schema:
```
{
  "removals": [
    {
      "computer": "name",
      "group": "name,
      "reason": "The computer is in an excluded group for this title"
    }
  ],
  "queuedCommands": [
    {
      "computer": 1,
      "commandUuid": "aaaaaaaa-3f1e-4b3a-a5b3-ca0cd7430937"
    }
  ],
  "errors": [
    {
      "computer": 2,
      "reason": "Device does not support the InstallEnterpriseApplication command"
    }
  ]
}
```