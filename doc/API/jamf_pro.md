# Endpoints related to Jamf Pro

<!-- ------------------------- -->
<a id="get_jamf_package_names"></a>
## GET /jamf/package-names

#### Purpose
List all Package Names known to Jamf Pro

#### Request
Type: None

#### Response
Type: JSON Array  
Schema:
```  
[
  "pkg name",
  ...
]
```

<!-- ------------------------- -->
<a id="get_jamf_computer_group_names"></a>
## GET /jamf/computer-group-names

#### Purpose
List all Computer Group Names known to Jamf Pro

#### Request
Type: None

#### Response
Type: JSON Array  
Schema:
```  
[
  "group name",
  ...
]
```

<!-- ------------------------- -->
<a id="get_jamf_category_names"></a>
## GET /jamf/category-names

#### Purpose
List all Category Names known to Jamf Pro

#### Request
Type: None

#### Response
Type: JSON Array  
Schema:
```  
[
  "category name",
  ...
]
```