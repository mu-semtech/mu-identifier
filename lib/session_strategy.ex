defmodule SessionStrategy do
  @moduledoc """
  Applies session clearing strategies shared across session enforcement manipulators.

  Each strategy returns `{headers, frontend_connection}` so the caller can
  forward the result directly without restructuring.
  """

  def apply(:clear_allowed_groups, frontend_connection, headers) do
    {headers, Plug.Conn.delete_session(frontend_connection, :mu_auth_allowed_groups)}
  end

  def apply(:clear_session, frontend_connection, headers) do
    old_session_id = Plug.Conn.get_session(frontend_connection, :proxy_user_id)

    frontend_connection =
      frontend_connection
      |> Plug.Conn.put_session(:proxy_user_id, Manipulators.EnsureUserSession.new_session_uri())
      |> Plug.Conn.delete_session(:mu_auth_allowed_groups)
      |> Plug.Conn.delete_session(:session_valid_until)
      |> Plug.Conn.assign(:session_valid_until, nil)

    {[{"mu-previous-session-id", old_session_id} | headers], frontend_connection}
  end

  def apply(nil, frontend_connection, headers) do
    {headers, frontend_connection}
  end
end
