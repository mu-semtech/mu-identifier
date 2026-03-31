defmodule SessionExpiration do
  @moduledoc """
  Handles session expiration strategies shared across session enforcement manipulators.

  Each strategy returns `{headers, frontend_connection}` so the caller can
  forward the result directly without restructuring.
  """

  def handle(strategy, frontend_connection, headers, label \\ nil)

  def handle(:clear_allowed_groups, frontend_connection, headers, _label) do
    frontend_connection =
      frontend_connection
      |> Plug.Conn.assign(:mu_auth_allowed_groups, nil)
      |> Plug.Conn.assign(:session_allowed_groups_set_at, nil)

    {headers, frontend_connection}
  end

  def handle(:clear_session, frontend_connection, headers, _label) do
    old_session_id = frontend_connection.assigns[:mu_session_id]
    new_session_id = Manipulators.Incoming.EnsureUserSession.new_session_uri()

    frontend_connection =
      frontend_connection
      |> Plug.Conn.assign(:mu_session_id, new_session_id)
      |> Plug.Conn.assign(:mu_auth_allowed_groups, nil)
      |> Plug.Conn.assign(:session_allowed_groups_set_at, nil)
      |> Plug.Conn.assign(:session_max_expires_at, nil)
      |> Plug.Conn.assign(:previous_session_id, old_session_id)

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
