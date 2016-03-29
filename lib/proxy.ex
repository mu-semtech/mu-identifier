defmodule Proxy do
  use Plug.Builder
  import Plug.Conn

  @target "http://dispatcher"

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

    conn = conn |> Plug.Conn.fetch_session |> ensure_user_session_id |> alter_request_headers

    IO.puts( inspect( Plug.Conn.get_session(conn, :proxy_user_id ) ) )

    {:ok, client} = :hackney.request(conn.method, uri(conn), conn.req_headers, :stream, [recv_timeout: 1500000000])

    conn
    |> write_proxy(client)
    |> read_proxy(client)
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

  defp alter_request_headers(conn) do
    cleaned_headers = List.keydelete( conn.req_headers, "Transfer-Encoding", 1 )
    new_headers = [ {"mu-session-id", Plug.Conn.get_session(conn, :proxy_user_id) } | cleaned_headers ]
    %{ conn | req_headers: new_headers }
  end

  # Reads the connection body and write it to the
  # client recursively.
  defp write_proxy(conn, client) do
    # Check Plug.Conn.read_body/2 docs for maximum body value,
    # the size of each chunk, and supported timeout values.
    case read_body(conn, []) do
      {:ok, body, conn} ->
        :hackney.send_body(client, body)
        conn
      {:more, body, conn} ->
        :hackney.send_body(client, body)
        write_proxy(conn, client)
    end
  end

  # Reads the client response and sends it back.
  defp read_proxy(conn, client) do
    {:ok, status, headers, client} = :hackney.start_response(client)
    {:ok, body} = :hackney.body(client)

    # Delete the transfer encoding header. Ideally, we would read
    # if it is chunked or not and act accordingly to support streaming.
    #
    # We may also need to delete other headers in a proxy.
    headers = List.keydelete(headers, "Transfer-Encoding", 1)

    %{conn | resp_headers: headers}
    |> send_resp(status, body)
  end

  defp uri(conn) do
    base = @target <> "/" <> Enum.join(conn.path_info, "/")
    case conn.query_string do
      "" -> base
      qs -> base <> "?" <> qs
    end
  end
end
