defmodule Proxy do
  use Plug.Builder

  @target "http://dispatcher"

  plug(Plug.Logger)
  plug(:put_secret_key_base)

  plug(Plug.Session,
    store: :cookie,
    key: "proxy_session",
    encryption_salt: Application.get_env(:mu_identifier, :encryption_salt),
    signing_salt: Application.get_env(:mu_identifier, :signing_salt),
    key_length: 64
  )

  plug(:dispatch)

  @request_manipulators [Manipulators.EnsureUserSession, Manipulators.AddCustomRequestHeaders]
  @response_manipulators [
    Manipulators.PutAllowedGroupsInSession,
    Manipulators.ClearMuInternalKeys,
    Manipulators.PutCacheClearHeaders,
    Manipulators.AddCorsHeader
  ]
  @manipulators ProxyManipulatorSettings.make_settings(
                  @request_manipulators,
                  @response_manipulators
                )

  def put_secret_key_base(conn, _) do
    put_in(conn.secret_key_base, Application.get_env(:mu_identifier, :secret_key_base))
  end

  def dispatch(conn, _opts) do
    # Start a request to the client saying we will stream the body.
    # We are simply passing all req_headers forward.

    # opts = PlugProxy.init url: uri(conn)

    ProxyManipulatorSettings.print_diagnostics(@manipulators)

    conn =
      conn
      |> Plug.Conn.fetch_session()

    ConnectionForwarder.forward(
      conn,
      Map.get(conn, :path_info),
      "http://dispatcher/",
      @manipulators
    )
  end
end
