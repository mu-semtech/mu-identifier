defmodule Proxy do
  use Plug.Builder

  @target "http://dispatcher"

  plug Plug.Logger
  plug :put_secret_key_base
  plug Plug.Session,
       store: :cookie,
       key: "proxy_session",
       encryption_salt: Application.get_env(:proxy, :encryption_salt),
       signing_salt: Application.get_env(:proxy, :signing_salt),
       key_length: 64
  plug :dispatch

  def put_secret_key_base(conn, _) do
    put_in conn.secret_key_base, Application.get_env(:proxy, :secret_key_base)
  end

  def start(_argv) do
    port = 80
    IO.puts "Running Proxy with Cowboy on port #{port}"

    Plug.Adapters.Cowboy.http __MODULE__, [], port: port
    :timer.sleep(:infinity)
  end

  defp add_processors(conn) do
    processors = %{
      header_processor: fn (headers, response_conn, state) ->

        headers = Enum.map( headers, fn( {name, value} ) -> {String.downcase(name),value} end )

        authorization =
          headers
          |> List.keyfind( "mu-auth-allowed-groups", 0, {nil,nil} )
          |> elem(1)

        response_conn =
          case authorization do
            "CLEAR" ->
              # Set CLEAR as the authorization group so we can pick it
              # up on the next request
              Plug.Conn.put_session( response_conn, :mu_auth_allowed_groups, authorization )
            nil -> response_conn
            _ -> Plug.Conn.put_session( response_conn, :mu_auth_allowed_groups, authorization )
          end

        # new_headers = [ {"mu-session-id", Plug.Conn.get_session(conn, :proxy_user_id) } | headers ]
        new_headers =
          headers
          |> List.keydelete( "x-cache", 0 )
          |> List.keydelete( "mu-auth-allowed-groups", 0 )
          |> List.keydelete( "mu-auth-used-groups", 0 )
          |> List.keydelete( "cache-keys", 0 )
          |> List.keydelete( "clear-keys", 0 )
          |> augment_cache_clear_headers
          |> add_cors_header

        { new_headers, state, response_conn }
      end,
      chunk_processor: fn (chunk, state) -> { chunk, state } end,
      body_processor: fn (body, state) -> { body, state } end,
      finish_hook: fn (state) -> { true, state } end,
      state: %{is_processor_state: true, body: "", headers: %{}, status_code: 200}
    }
    Map.put( conn, :processors, processors )
  end

  defp augment_cache_clear_headers( headers ) do
    # When the cache is not set, or when it is "no-cache", we inform
    # browsers in all headers available to us to not add any caches.

    # Some browsers (IE) handle caching differently than their peers.
    # The mu-identifier makes this easier to support by providing the
    # necessary headers.

    cache_clear_header =
      headers
      |> List.keyfind( "cache-control", 0, {nil,:no_cache_control_header} )
      |> elem(1)

    case cache_clear_header do
      "no-cache" ->
        headers
        |> put_new_key( "pragma", "no-cache" )
        |> put_new_key( "expires", "-1" )
      :no_cache_control_header ->
        headers
        |> put_new_key( "pragma", "no-cache" )
        |> put_new_key( "expires", "-1" )
        |> put_new_key( "cache-control", "no-cache" )
      _ -> headers
    end
  end

  defp add_cors_header( headers ) do
    # Adds the CORS header to the list of headers
    cors_header = Application.get_env(:proxy, :cors_header)

    if cors_header do
      put_new_key( headers, "Access-Control-Allow-Origin", cors_header )
    else
      headers
    end
  end

  def dispatch(conn, _opts) do
    # Start a request to the client saying we will stream the body.
    # We are simply passing all req_headers forward.
    opts = PlugProxy.init url: uri(conn)

    conn
    |> Plug.Conn.fetch_session
    |> ensure_user_session_id
    |> add_custom_request_headers
    |> add_processors
    |> PlugProxy.call( opts )
  end

  defp ensure_user_session_id (conn) do
    if Plug.Conn.get_session(conn, :proxy_user_id) do
      IO.puts( "keeping user_id" )
      conn
    else
      IO.puts( "creating new rand user_id" )
      Plug.Conn.put_session(conn, :proxy_user_id, "http://mu.semte.ch/sessions/" <> UUID.uuid1())
    end
  end

  defp add_custom_request_headers(conn) do
    headers = conn.req_headers

    # Clean all information which we are owner of within the stack
    clean_headers =
      headers
      |> List.keydelete( "mu-session-id", 0 )
      |> List.keydelete( "mu-call-id", 0 )
      |> List.keydelete( "mu-auth-allowed-groups", 0 )

    new_headers =
      [ {"mu-session-id", Plug.Conn.get_session(conn, :proxy_user_id) },
        {"mu-call-id", Integer.to_string( Enum.random( 0..1_000_000_000_000 ) )}
        | clean_headers ]

    authorization_groups = Plug.Conn.get_session( conn, :mu_auth_allowed_groups )
    default_allowed_groups = Application.get_env(:proxy, :default_mu_auth_allowed_groups)

    headers_with_authorization = cond do
      authorization_groups == "CLEAR" ->
        new_headers
      authorization_groups ->
        [ { "mu-auth-allowed-groups", authorization_groups } | new_headers ]
      default_allowed_groups ->
        [ { "mu-auth-allowed-groups", default_allowed_groups } | new_headers ]
      true ->
        new_headers
    end

    %{ conn | req_headers: headers_with_authorization }
  end

  defp uri(conn) do
    base = @target <> "/" <> Enum.join(conn.path_info, "/")
    case conn.query_string do
      "" -> base
      qs -> base <> "?" <> qs
    end
  end

  def put_new_key( list, key, value ) do
    # Adds the key/value tuple to the list, unless it is already there

    if List.keymember?( list, key, 0 ) do
      list
    else
      [ { key, value } | list ]
    end
  end
end
