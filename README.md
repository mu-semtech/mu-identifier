# mu-identifier

An HTTP proxy for identifying sessions so microservices can act on them.

The mu-identifier doesn't have much information on the user's session.  It identifies a specific Browser Agent (a specific browser on a specific device) so other services can attach information to them.  The session identifier is passed through the `MU-SESSION-ID` header to the backend services. The identifier is also responsible for other things in which we detect the user, currently caching the access rights of the current user.

## Tutorials

### Add the identifier to a stack

The mu-identifier is the place where requests arrive.  The identifier is published on port 80 on servers which only run one application.  A development environment could be an example.

Add the identifier to the services block of your docker-compose.yml

    services:
      identifier:
        image: semtech/mu-identifier:1.9.1
        links:
           - dispatcher:dispatcher

As a primitive, the identifier will forward all requests to the dispatcher.  This snippet is sufficient to add the identifier to a stack.

## How-to guides

### How to make a stack accessible from an external host (CORS)

Cross Origin Resource Sharing is a method which allows a browser visiting domain A to use an API on domain B.

When an external site is being used as an API, the browser sends an OPTIONS request and checks the `Access-Control-Allow-Origin` header for a valid remote source.  `*` is used as a value to allow access from all remote hosts.  That's what we'll use in this example.

NOTE: There are some caveats to our approach.  In order to pass the coookie through some extra headers may need to be sent (common are `access-control-allow-headers: content-type,accept` and `access-control-allow-methods: *`).  If you need support for this, create a PR or discuss in an issue.

The identifier can add this header to any response.  We do this by setting the `DEFAULT_ACCESS_CONTROL_ALLOW_ORIGIN_HEADER` value.  This can either be applied to the docker-compose.yml or to the docker-compose.override.yml based on the intended use.  We will assume the application is always considered public and add it to the docker-compose.yml

    services:
      identifier:
        ...
        environment:
          DEFAULT_ACCESS_CONTROL_ALLOW_ORIGIN_HEADER: "*"

To make the identifier pick up this change, we need to recreate the service with the new environment variable:

    > cd /path/to/your/app
    > docker-compose up -d

Next up, we need to make sure we always respond with a positive answer to the remote options calls.  The easiest way to accomplish this is to send a 200 for any OPTIONS call that hits the dispatcher.  You might need something more fancy, but most services don't actively cater for the OPTIONS call.

    # /config/dispatcher.ex
    options "*_path" do
      send_resp( conn, 200, "Option calls are accepted by default" )
    end

In order to ensure the dispatcher picks up the new route, we have to restart the dispatcher.

    > cd /path/to/your/app
    > docker-compose restart dispatcher

Done, your API can now be accessed from external sources.

### Recalculate allowed groups after login

If a service updates the access rights of the current session and does not calculate the access rights itself, it must inform the identifier to clear the `mu-auth-allowed-groups` header and refrain from setting it in the next call.

It is advised for a login system to set the correct access rights, but it's not required in most cases.  This allows the login service to be ever so slightly simpler.  A service that operates this way needs to send a `CLEAR` value in the `mu-auth-allowed-groups` as its response.

A JavaScript service could look like this:

    # app.js
    app.post('/login', function (req, res) {
      // update database state
      res
        .header( 'mu-auth-allow-groups', 'CLEAR' )
        .send( /* body */ );
    });

This will ensure that the next request the user asks, when it hits the database, calculates the new `mu-auth-allowed-groups` value.

### Allow cache hits for new requests

The first call a user executes which may have been cached beforehand will likely not hit the cache.  In this tutorial we will fix that for an example stack.

Caches respond to requests based on the access rights attached to the session, but when a user first requests data, there are no known access rights.  The access rights are calculated when a user's request hits the database for the first time.  We must therefore supply access rights for users that don't have access rights yet.  The mu-identifier has support for defining such access rights.

The first thing we have to do is finding the access rights for users that are not logged in.  This could be some complex access right but in practice they tend to be very straight-forward.  We can find the access rights by finding the definition in mu-authorization.  For every `%GroupSpec{}` which has an access of `%AlwaysAccessible{}` we note down the name of the access right.  A common array of access rights would then be `[public, clean]`.

These group names should be converted into a valid `mu-auth-allowed-groups` header string.  More information on this can be found in the mu-authorization documentation.  For this task it suffices to state that the header string is a JSON stringified version of an array containing individual allowed groups.  Each allowed group in turn is an object which has a `name` key containing the name of the group and a `variables` key which contcains an array of specializations of the group (in our case an empty array).

We can convert the previous section to the following JSON string:

    "[{\"variables\":[],\"name\":\"public\"},{\"variables\":[],\"name\":\"clean\"}]"

This JSON string can be set in the environment of the mu-identifier.  It is common to place this in the docker-compose.yml as it is an application-wide setting that is most often shared across environments.

    # docker-compose.yml
    services:
      identifier:
        environment:
          DEFAULT_MU_AUTH_ALLOWED_GROUPS_HEADER: "[{\"variables\":[],\"name\":\"public\"},{\"variables\":[],\"name\":\"clean\"}]"

In order to set this string, we need to recreate the identifier with the new environment variables.

    > cd /path/to/your/app
    > docker-compose up -d

### Log the allowed groups in a running stack

A running stack should have an identifier.  In the docker-compose.yml it should be in the `identifier` service.  The `Mu-Auth-Allowed-Groups` header is received from the user's cookie (if it was calculated) and is sent back to the user.  Overrides of this kind are most often stored in the `docker-compose.override.yml` because they tend to be deployment-specific.

    # docker-compose.override.yml
    version: "3.4"
    services:
      identifier:
        image: ...
        links:
          ...
        environment:
          LOG_ALLOWED_GROUPS: "on"

After adding the environment variable, you have to pull the changes into the container

    > cd /path/to/your/app
    > docker-compose up -d


## Discussions

### What is the core function of mu-identifier

The mu-identifier is the first service through which all requests pass.  It's prime responsibility is to know which user is sending requests.  The identifier itself is not connected to the database, it can only reason on the information it receives and pass it on.

Because the identifier is the single and first place where things enter on the stack it is a good place to add logic for cleaning up responses, generically enriching requests as well as maintaining the session state.  As such, the role of the identifier is scoped by its unique position in the stack and by its limitations, more than by a strict set of rules of what it may store or how it must function.

As such the identifier currently ends up being responsible for:

  - setting the user agent
  - cleaning response headers
  - making caching easier
  - caching user authorization groups


### Can this service be replaced by another proxy like Nginx?

Theorethically this service could be replaced by another technology.  In order to keep things consistent, and to ensure we have some freedom to adapt the logic in a way we can control, using a custom proxy makes sense.  In order to have some freedom over the processing of requests a single code base makes much sense.

An example of such alterations is the caching of mu-auth-allowed-groups.  Microservices should pass this header along but it should normally not be shared with the outside world.  Because we have the mu-identifier service in place we can transparantly introduce such a feature without impacting other stacks.

### Why is this Elixir

Great question!  Elixir runs on the BEAM which is great at maintaining long running connections with little overhead.  It is also fault-tolerant, making it harder to crash the application should bugs appears.  Elixir is arguably more readable than Erlang, hence the choice.

## Reference

All settings are configured through environment variables.

### External hosts

`http://dispatcher/`: The mu-identifier forwards requests to `http://dispatcher/` add a link if a different backend needs to be accessed.

### Environment variables

* `DEFAULT_ACCESS_CONTROL_ALLOW_ORIGIN_HEADER`: value of the `Access-Control-Allow-Origin` header if none is set by the backend.
* `DEFAULT_MU_AUTH_ALLOWED_GROUPS_HEADER`: string used as default `Mu-Auth-Allowed-Groups` for sessions which don't contain these groups yet and which may use defaults (eg: `"[{\"variables\":[],\"name\":\"public\"}]"`).
* `MU_SECRET_KEY_BASE`: base string of base string of at least 64 bytes used to generate secret keys, set this on production systems to avoid overlap.
* `MU_ENCRYPTION_SALT`: a salt used with `MU_SECRET_KEY_BASE` to generate a key for encrypting/decrypting a cookie, set this on production systems so sessions survive restarts of the identifier.
* `MU_SIGNING_SALT`: a salt used with `MU_SECRET_KEY_BASE` to generate a key for signing/verifying a cookie, set this on production systems so sessions survive restarts of the identifier.
* `LOG_INCOMING_ALLOWED_GROUPS`: log incoming allowed groups set on the incoming request when set to "true", "yes", "1" or "on".
* `LOG_OUTGOING_ALLOWED_GROUPS`: log outgoing allowed groups set on the outgoing response when set to "true", "yes", "1" or "on".
* `LOG_ALLOWED_GROUPS`: log incoming as well as outgoing allowed groups when set to "true", "yes", "1" or "on".
* `LOG_SESSION`: log session ids, both created as well as kept when set to "true", "yes", "1" or "on".
* `SESSION_COOKIE_SECURE`: Set SECURE flag of the session cookie (see [MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie))
* `SESSION_COOKIE_HTTP_ONLY`: Set HTTP_ONLY flag of the session cookie (see [MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie)), on by default.
* `SESSION_COOKIE_SAME_SITE`: Set SAME_SITE flag of the session cookie (see [MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie)), "Lax" by default unless `DEFAULT_ACCESS_CONTROL_ALLOW_ORIGIN_HEADER` is "*" then "None" by default.  This means the cookie is available only on your site unless you've also set the CORS header.
* `IDLE_TIMEOUT`: the amount of time (in ms) that idle requests will be kept open (see `idle_timeout` in the [Cowboy docs](https://ninenines.eu/docs/en/cowboy/2.5/manual/cowboy_http/))

### Special headers

#### Passes `Mu-Session-Id` to backend

The identifier generates a unique URI for each Browser Agent. It passes this session identifier via the `Mu-Session-Id` to the backend. The microservices in the backend can use the value passed in the header to attach data to the user's session in the store.

#### Received `Mu-Auth-Allowed-Groups` from backend

The last received `Mu-Auth-Allowed-Groups` is considered to contain the current access rights of the user.  A backend putting `Clear` in these access rights requests the rights to be cleared, and no `Mu-Auth-Allowed-Groups` to be supplied to the backend in the subsequent request, effectively causing a recalculation of the `Mu-Auth-Allowed-Groups` by the backend.

#### Received `Cache-Control` from backend

When no `Cache-Control` header is supplied or the header contains `no-cache` the following headers are sent out:

    cache-control: no-cache
    pragma: no-cache
    expires: -1
