defmodule Proxy do
  use Plug.Builder

  @target "http://dispatcher/"
  @encryption_salt Application.get_env(:mu_identifier, :encryption_salt) ||
                     SecureRandom.urlsafe_base64(128)
  @signing_salt Application.get_env(:mu_identifier, :signing_salt) || SecureRandom.urlsafe_base64(128)

  plug(Plug.Logger)
  plug(:put_secret_key_base)

  plug Replug,
    plug: { Plug.Session,
            store: :cookie,
            key: "proxy_session",
            encryption_salt: { Proxy, :encryption_salt, [] },
            signing_salt: { Proxy, :signing_salt, [] },
            key_length: 64 },
    opts: { Proxy, :opts_from_environment }

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

  def encryption_salt do
    @encryption_salt
  end

  def signing_salt do
    @signing_salt
  end

  def opts_from_environment do
    [
      secure: IO.inspect(Application.get_env(:mu_identifier, :session_cookie_secure), label: "SECURE?"),
      http_only: Application.get_env(:mu_identifier, :session_cookie_http_only),
      same_site: Application.get_env(:mu_identifier, :session_cookie_same_site)
    ]
  end

end
