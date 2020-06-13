defmodule Proxy do
  use Plug.Builder

  @target "http://dispatcher/"
  @encryption_salt Application.get_env(:proxy, :encryption_salt) ||
                     SecureRandom.urlsafe_base64(128)
  @signing_salt Application.get_env(:proxy, :signing_salt) || SecureRandom.urlsafe_base64(128)

  plug(Plug.Logger)
  plug(:put_secret_key_base)

  plug(Plug.Session,
    store: :cookie,
    key: "proxy_session",
    secure: true,
    http_only: true,
    same_site: "lax"
    encryption_salt: @encryption_salt,
    signing_salt: @signing_salt,
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
    put_in(conn.secret_key_base, Secret.secret_key_base())
  end

  def dispatch(conn, _opts) do
    conn =
      conn
      |> Plug.Conn.fetch_session()

    ConnectionForwarder.forward(
      conn,
      Map.get(conn, :path_info),
      @target,
      @manipulators
    )
  end
end
