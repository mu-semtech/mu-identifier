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
            key_length: 32 }, # 32 bytes = 256bit which we need for the current cypher
    opts: { Proxy, :opts_from_environment }

  plug(:dispatch)

  @request_manipulators [
    Manipulators.Incoming.LogRequest,
    Manipulators.Incoming.CustomSessionReader,
    Manipulators.Incoming.ReadSessionFromCookie,
    Manipulators.Incoming.ReadSessionFromJwt,
    Manipulators.Incoming.ClientEnforcedSessionClearing,
    Manipulators.Incoming.EnsureUserSession,
    Manipulators.Incoming.HandleInvalidCredentials,
    Manipulators.Incoming.EnforceSessionRevocations,
    Manipulators.Incoming.EnforceSessionLifetime,
    Manipulators.Incoming.EnforceSessionKeepalive,
    Manipulators.Incoming.ClearIncomingHeaders,
    Manipulators.Incoming.AddCustomRequestHeaders
  ]
  @response_manipulators [
    Manipulators.Outgoing.LogRequest,
    Manipulators.Outgoing.ReinstateRevokedSession,
    Manipulators.Outgoing.PutAllowedGroupsInSession,
    Manipulators.Outgoing.UpdateSessionLifetime,
    Manipulators.Outgoing.UpdateSessionKeepalive, # consider placing this after ClearOutgoingHeaders
    Manipulators.Outgoing.DetermineSessionDeliveryMode,
    Manipulators.Outgoing.ClearOutgoingHeaders,
    Manipulators.Outgoing.PutCacheClearHeaders,
    Manipulators.Outgoing.AddCorsHeader,
    Manipulators.Outgoing.OverrideVaryHeader,
    Manipulators.Outgoing.CustomSessionWriter,
    Manipulators.Outgoing.WriteSessionCookie,
    Manipulators.Outgoing.WriteJwtToken
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
      secure: Application.get_env(:mu_identifier, :session_cookie_secure),
      http_only: Application.get_env(:mu_identifier, :session_cookie_http_only),
      same_site: Application.get_env(:mu_identifier, :session_cookie_same_site)
    ]
  end

end
