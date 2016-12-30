defmodule Proxy do
  use Plug.Builder

  @target "http://dispatcher/"

  plug Plug.Logger
  plug :put_secret_key_base
  plug Plug.Session,
       store: :cookie,
       key: "proxy_session",
       encryption_salt: "asnotheu etahoeu ta. toa. uao.c", # TODO use ENV instead
       signing_salt: "saoteh aosethu aosntehu .b, m.u .0aom .0a", # TODO use ENV instead
       key_length: 64
  plug :dispatch

  def put_secret_key_base(conn, _) do
    put_in conn.secret_key_base, "ZOMG this is a log string with at least 64 bytes in it... wiiiide!" # TODO use ENV instead
  end

  def start(_argv) do
    port = 80
    IO.puts "Running Proxy with Cowboy on http://localhost:#{port}"

    Plug.Adapters.Cowboy.http __MODULE__, [], port: port
    :timer.sleep(:infinity)
  end

  def dispatch(conn, _opts) do
    # Start a request to the client saying we will stream the body.
    # We are simply passing all req_headers forward.

    conn = conn
    |> Plug.Conn.fetch_session
    |> ensure_user_session_id
    |> add_custom_request_headers

    # IO.puts( inspect( Plug.Conn.get_session(conn, :proxy_user_id ) ) )

    processors = %{
      header_processor: fn (headers, state) ->
        new_headers = [ {"mu-session-id", Plug.Conn.get_session(conn, :proxy_user_id) } | headers ]
        { new_headers, state }
      end,
      chunk_processor: fn (chunk, state) -> { chunk, state } end,
      body_processor: fn (body, state) -> { body, state } end,
      finish_hook: fn (state) -> { true, state } end,
      state: %{is_processor_state: true, body: "", headers: %{}, status_code: 200}
    }

    opts = PlugProxy.init url: uri(conn)
    conn
    |> Map.put( :processors, processors )
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
