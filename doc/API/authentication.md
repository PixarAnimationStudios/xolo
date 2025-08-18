# Endpoints related to Authentication

For more info about authentication, see the `KEYS` constant of `lib/xolo/server/configuration.rb`

<!-- ------------------------- -->
<a id="post_auth_login"></a>
## POST /auth/login

#### Purpose
Authenticate to the Xolo server and acquire a session cookie. 

#### Notes
The 'rack.session' cookie that comes back with this or any subequent response, must be included in the next request made for this session.

This endpoint does not require authentication (obviously).

#### Request
Type: JSON Object  
Schema: 
```
{
  "admin": "adminLogin",
  "password": "admin pw"
}
```

#### Response
Type: JSON Object  
Schema:
```  
{
  "admin": "adminLogin",
  "authenticated": true
}
```

<!-- ------------------------- -->
<a id="post_auth_logout"></a>
## POST /auth/logout

#### Purpose
Log out the currently authenticated admin, and invalidate the session.

#### Request
Type: None

#### Response
Type: JSON Object  
Schema:
```  
{
  "authenticated": false
}
```

<!-- ------------------------- -->
<a id="get_release_to_all_allowed"></a>
## GET /auth/release_to_all_allowed

#### Purpose
Check if the current admin is allowed to set a titles release groups to 'all'

#### Request
Type: None

#### Response
Type: JSON Object  
Schema:
```  
{
  "allowed": boolean,
  "msg": "text message about getting access to release to all"
}
```