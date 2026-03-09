defmodule SessionExpiration do
  @moduledoc """
  Handles session expiration strategies shared across session enforcement manipulators.

  Each strategy returns `{headers, frontend_connection}` so the caller can
  forward the result directly without restructuring.
  """

  def handle(:clear_allowed_groups, frontend_connection, headers) do
    frontend_connection =
      frontend_connection
      |> Plug.Conn.assign(:mu_auth_allowed_groups, nil)
      |> Plug.Conn.assign(:groups_issued_at, nil)

    {headers, frontend_connection}
  end

  def handle(:clear_session, frontend_connection, headers) do
    old_session_id = frontend_connection.assigns[:mu_session_id]
    new_session_id = Manipulators.EnsureUserSession.new_session_uri()

    frontend_connection =
      frontend_connection
      |> Plug.Conn.assign(:mu_session_id, new_session_id)
      |> Plug.Conn.assign(:mu_auth_allowed_groups, nil)
      |> Plug.Conn.assign(:groups_issued_at, nil)
      |> Plug.Conn.assign(:session_valid_until, nil)

    {[{"mu-previous-session-id", old_session_id} | headers], frontend_connection}
  end

  def handle(:unauthorized, frontend_connection, headers) do
    frontend_connection =
      frontend_connection
      |> Plug.Conn.send_resp(401, "")
      |> Plug.Conn.halt()

    {headers, frontend_connection}
  end

  def handle(nil, frontend_connection, headers) do
    {headers, frontend_connection}
  end
end
