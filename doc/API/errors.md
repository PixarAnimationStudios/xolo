# Error Responses

All error responses should contain the following JSON Object. 

The 'status' value should match the HTTP error status, usually 4xx or 5xx

```
  {
    "status": Integer,
    "error": "message"
  }
```
