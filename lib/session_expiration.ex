defmodule SessionExpiration do
  @moduledoc """
  Handles session expiration strategies shared across session enforcement manipulators.

  Each strategy returns `{headers, frontend_connection}`.
  """

  def handle(strategy, frontend_connection, headers, label \\ nil)

  def handle(:clear_allowed_groups, frontend_connection, headers, _label) do
    frontend_connection =
      frontend_connection
      |> Plug.Conn.assign(:cleared_mu_auth_allowed_groups, frontend_connection.assigns[:mu_auth_allowed_groups])
      |> Plug.Conn.assign(:mu_auth_allowed_groups, nil)
      |> Plug.Conn.assign(:session_allowed_groups_set_at, nil)

    {headers, frontend_connection}
  end

  def handle(:clear_session, frontend_connection, headers, _label) do
    frontend_connection =
      frontend_connection
      |> Plug.Conn.assign(:cleared_mu_session_id, frontend_connection.assigns[:mu_session_id])
      |> Plug.Conn.assign(:cleared_mu_auth_allowed_groups, frontend_connection.assigns[:mu_auth_allowed_groups])
      |> Plug.Conn.assign(:mu_session_id, Manipulators.Incoming.EnsureUserSession.new_session_uri())
      |> Plug.Conn.assign(:mu_auth_allowed_groups, nil)
      |> Plug.Conn.assign(:session_allowed_groups_set_at, nil)
      |> Plug.Conn.assign(:session_lifetime_expires_at, nil)
      |> Plug.Conn.assign(:session_last_activity_at, nil)
      |> Plug.Conn.assign(:jwt_token_unreadable, nil)
      |> Plug.Conn.assign(:previous_session_state, nil)
      |> Plug.Conn.assign(:session_cookie_unreadable, nil)
      |> Plug.Conn.assign(:session_delivery_mode, :cookie)
      |> Plug.Conn.assign(:session_cookie_unreadable, nil)
      |> Plug.Conn.assign(:session_revocation_reasons, [])

    {headers, frontend_connection}
  end

  def handle(:unauthorized, frontend_connection, headers, label) do
    reasons = frontend_connection.assigns[:session_revocation_reasons] || []

    reasons =
      if label do
        [label | reasons]
      else
        reasons
      end

    {headers,
     frontend_connection
     |> Plug.Conn.assign(:mu_unauthorized, true)
     |> Plug.Conn.assign(:session_revocation_reasons, reasons)}
  end

  def handle(nil, frontend_connection, headers, _label) do
    {headers, frontend_connection}
  end
end
