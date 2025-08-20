# General Purpose Endpoints

<!-- ------------------------- -->
<a id="get_ping"></a>
## GET /ping

#### Purpose
Check server availability

#### Notes
This endpoint does not require authentication.

This endpoint does not return JSON

#### Request
None

#### Response
Type: String

Value: 
```
pong
```

<!-- ------------------------- -->
<a id="get_streamed_progress"></a>
## GET /streamed_progress/?stream_file={url-escaped/path/to/file/on/server}

#### Purpose
Stream the progress of a long-running task in real time.

#### Notes
Requests that start long-running tasks on the server will return a path to be used with this endpoint. GETting the endpoint with that path will start a real-time streamed response of text, one line at a time, showing the progress of the task.

#### Query Parameters
`stream_file` - path to the stream on the server, provided in the last server response

#### Request
Type: None

#### Response
Type: Raw HTTP streaming response

Value: Lines of text showing the progress.

