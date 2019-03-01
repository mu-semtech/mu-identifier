# mu-identifier

An HTTP proxy for identifying sessions so microservices can act on them.  This service proxies the user's request to http://dispatcher/ and adds the `MU-SESSION-ID` header with an identifier of the current session.

The following environment variables must be configured:
* `MU_SECRET_KEY_BASE`: base string of at least 64 bytes used to generate secret keys
* `MU_ENCRYPTION_SALT`: a salt used with `MU_SECRET_KEY_BASE` to generate a key for encrypting/decrypting a cookie
* `MU_SIGNING_SALT`: a salt used with `MU_SECRET_KEY_BASE` to generate a key for signing/verifying a cookie
* `DEFAULT_ACCESS_CONTROL_ALLOW_ORIGIN_HEADER`: value of the `Access-Control-Allow-Origin` header if it should be set by the identifier
* `DEFAULT_MU_AUTH_ALLOWED_GROUPS_HEADER`: string used as default `MU_AUTH_ALLOWED_GROUPS` for sessions which don't contain these groups yet. (eg: `"[{\"variables\":[],\"name\":\"public\"}]"`)
