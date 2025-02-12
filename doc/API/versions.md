# Endpoints related to Xolo Versions

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
URLs for all the Title Editor and Jamf WebApp pages related to a title

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
