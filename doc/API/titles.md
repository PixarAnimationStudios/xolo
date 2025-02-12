# Endpoints related to Xolo Titles

<!-- ------------------------- -->
<a id="get_titles"></a>
## GET /titles

#### Purpose
List all title objects known to xolo

#### Request
Type: None

#### Response
Type: JSON Array of [Xolo Title Objects](title-schema.md)  
Schema:
```  
[
  {Title Object},
  ...
]
```

<!-- ------------------------- -->
<a id="post_titles"></a>
## POST /titles

#### Purpose
Create a title object

#### Request
Type: JSON Object  
Schema: [Xolo Title Object](title-schema.md)

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
<a id="get_title"></a>
## GET /titles/{title}

#### Purpose
Fetch a title object

#### Path Parameters
`title` - the desired title

#### Request
Type: None

#### Response
Type: JSON Object  
Schema: [Xolo Title Object](title-schema.md)  


<!-- ------------------------- -->
<a id="put_title"></a>
## PUT /titles/{title}

#### Purpose
Update a title object

#### Path Parameters
`title` - the desired title

#### Request
Type: JSON Object  
Schema: [Xolo Title Object](title-schema.md)

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
<a id="delete_title"></a>
## DELETE /titles/{title}

#### Purpose
Delete a title object and all it's versions

#### Path Parameters
`title` - the desired title

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
<a id="upload_ssvc_icon"></a>
## POST /titles/{title}/ssvc-icon

#### Purpose
Upload a Self-Service icon for a title

#### Path Parameters
`title` - the desired title

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
<a id="frozen_computers"></a>
## GET /titles/{title}/frozen

#### Purpose
List members of the 'frozen' group for a title.

#### Path Parameters
`title` - the desired title

#### Request
Type: none

#### Response
Type: JSON Object  
Schema:
```
{
  "computer name": "user name",
  ...
}
```

<!-- ------------------------- -->
<a id="freeze_computers"></a>
## PUT /titles/{title}/freeze

#### Purpose
Add one or more computers to the 'frozen' group for a title

#### Path Parameters
`title` - the desired title

#### Request
Type: JSON Array  
Schema:
```
[
  "computer name",
  ...
]
```

#### Response
Type: JSON Object  
Schema:
```
{
  "computer name": "result of freezing attempt",
  ...
}
```

<!-- ------------------------- -->
<a id="thaw_computers"></a>
## PUT /titles/{title}/thaw

#### Purpose
Remove one or more computers from the 'frozen' group for a title

#### Path Parameters
`title` - the desired title

#### Request
Type: JSON Array  
Schema:
```
[
  "computer name",
  ...
]
```

#### Response
Type: JSON Object  
Schema:
```
{
  "computer name": "result of thawing attempt",
  ...
}
```

<!-- ------------------------- -->
<a id="patch_report"></a>
## GET /titles/{title}/patch_report

#### Purpose
Return info about all computers with a given title installed

#### Path Parameters
`title` - the desired title

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
## GET /titles/{title}/urls

#### Purpose
URLs for all the Title Editor and Jamf WebApp pages related to a title

#### Notes
Keys of the response object will vary depending on the state of the title

#### Path Parameters
`title` - the desired title

#### Request
Type: none

#### Response
Type: JSON Object  
Schema:
```
{
  "ted_title_url": "url",
  "jamf_installed_group_url": "url",
  "jamf_frozen_group_url": "url",
  "jamf_uninstall_script_url": "url",
  "jamf_uninstall_policy_url": "url",
  "jamf_expire_policy_url": "url",
  "jamf_patch_title_url": "url",
  "jamf_patch_ea_url": "url",
  "jamf_normal_ea_url": "url"
}
```

<!-- ------------------------- -->
<a id="changelog"></a>
## GET /titles/{title}/changelog

#### Purpose
URLs for all the Title Editor and Jamf WebApp pages related to a title

#### Notes
Each change object might indicate
  - a change to overall title state, in which case "attrib" is nil, but "msg" will contain a message
  - a change to a title attribute/property, in which case "attrib" will name it, and the old and new values are present
  - a change to a version state or version attribute/propery, in which case "version" will contain the version.

#### Path Parameters
`title` - the desired title

#### Request
Type: none

#### Response
Type: JSON Array of JSON Objects  
Schema:
```
[
  {
    "time": "2024-12-02 14:06:05 -0800",
    "admin": "chrisl",
    "host": "kekoa.dynamic.pixar.com",
    "version": null,
    "msg": "Title Created",
    "attrib": null,
    "old": null,
    "new": null
  },
  ...
]
```