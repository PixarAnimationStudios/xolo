# Endpoints related to Xolo server maintenance

These endpoints require the admin to be a member of the `server_admin_jamf_group` defined in the server config. 

See they `KEYS` constant defined in `lib/xolo/server/configuration.rb`

<!-- ------------------------- -->
<a id="get_maint_threads"></a>
## GET /maint/threads

#### Purpose
Inspect the current threads being used by the server process

#### Request
Type: None

#### Response
Type: JSON Object  
Schema:
```  
{
  "Thread Name": "Thread Status",
  ...
}

```

<!-- ------------------------- -->
<a id="get_maint_state"></a>
## GET /maint/state

#### Purpose
Get server state details

#### Request
Type: None

#### Response
Type: JSON Object  
Schema:
```  
{
  executable: "string",
  start_time: "string",
  uptime: "string",
  app_env: "string",
  data_dir: "string",
  log_file: "string",
  log_level: "string",
  ruby_version: "string",
  xolo_version: "string"N,
  ruby_jss_version: "string"
  windoo_version: "string",
  config: JSON Object,
  pkg_deletion_pool: JSON Object,
  object_locks: JSON Object,
  threads: JSON Object
}
```

<!-- ------------------------- -->
<a id="post_maint_cleanup"></a>
## POST /maint/cleanup

#### Purpose
Manually the server's cleanup process

#### Request
Type: None

#### Response
Type: JSON Object  
Schema:
```  
{
  "result": "Manual Cleanup Underway"
}
```

<!-- ------------------------- -->
<a id="post_maint_update_client_data"></a>
## POST /maint/update-client-data

#### Purpose
Force an update of the client data

#### Request
Type: None

#### Response
Type: JSON Object  
Schema:
```  
{
  "result": "Client Data Update underway"
}
```

<!-- ------------------------- -->
<a id="post_maint_rotate_logs"></a>
## POST /maint/rotate-logs

#### Purpose
Manually rotate the server logs

#### Request
Type: None

#### Response
Type: JSON Object
Schema:
```  
{
  "result": "Log rotation underway"
}
```

<!-- ------------------------- -->
<a id="post_maint_set_log_level"></a>
## POST /maint/set-log-level

#### Purpose
Set the server's log level

#### Request
Type: JSON Object  
Schema:
```
{
  "level": "level"
}
```

#### Response
Type: JSON Object  
Schema:
```  
{
  "result": "Log level set to #{level}"
}
```

<!-- ------------------------- -->
<a id="post_maint_shutdown_server"></a>
## POST /maint/shutdown-server

#### Purpose
Shut down or restart the server

#### Request
Type: JSON Object  
Schema:
```
{
  "restart": boolean
}
```

#### Response
Type: JSON Object 
Schema:
```  
{
  "status": 'running',
  "progress_stream_url_path": "path/for/streaming/output"
}
```