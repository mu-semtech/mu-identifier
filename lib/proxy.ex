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

        authorization =
          headers
          |> List.keyfind( "mu-auth-allowed-groups", 0, {nil,nil} )
          |> elem(1)

        response_conn =
          case authorization do
            "CLEAR" -> Plug.Conn.delete_session( response_conn, :mu_auth_allowed_groups )
            nil -> response_conn
            _ -> Plug.Conn.put_session(response_conn, :mu_auth_allowed_groups, authorization)
          end

        # new_headers = [ {"mu-session-id", Plug.Conn.get_session(conn, :proxy_user_id) } | headers ]
        new_headers =
          headers
          |> List.keydelete( "X-Cache", 0 )
          |> List.keydelete( "mu-auth-allowed-groups", 0 )
          |> List.keydelete( "mu-auth-used-groups", 0 )

        { new_headers, state, response_conn }
      end,
      chunk_processor: fn (chunk, state) -> { chunk, state } end,
      body_processor: fn (body, state) -> { body, state } end,
      finish_hook: fn (state) -> { true, state } end,
      state: %{is_processor_state: true, body: "", headers: %{}, status_code: 200}
    }
    Map.put( conn, :processors, processors )
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
    new_headers = [ {"mu-session-id", Plug.Conn.get_session(conn, :proxy_user_id) },
                    {"mu-call-id", Integer.to_string( Enum.random( 0..1_000_000_000_000 ) )}
                    | headers ]

    authorization_groups = Plug.Conn.get_session( conn, :mu_auth_allowed_groups )

    new_headers = if authorization_groups do
      [ { "mu-auth-allowed-groups", authorization_groups }
        | new_headers ]
    else
      new_headers
    end

    %{ conn | req_headers: new_headers }
  end

  defp uri(conn) do
    base = @target <> "/" <> Enum.join(conn.path_info, "/")
    case conn.query_string do
      "" -> base
      qs -> base <> "?" <> qs
    end
  end
end
