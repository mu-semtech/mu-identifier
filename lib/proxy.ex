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
      header_processor: fn (headers, state) ->
        # new_headers = [ {"mu-session-id", Plug.Conn.get_session(conn, :proxy_user_id) } | headers ]
        # headers = List.keydelete( headers, "X-Cache", 0 )
        { headers, state }
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
    new_headers = [ {"mu-session-id", Plug.Conn.get_session(conn, :proxy_user_id) } | headers ]
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
