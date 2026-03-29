defmodule Manipulators.ReadSessionFromCookie do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    if Application.get_env(:mu_identifier, :debug_session) do
      IO.inspect(Plug.Conn.get_session(frontend_connection, :mu_session_id), label: "Session id from cookie")
    end

    frontend_connection =
      frontend_connection
      |> Plug.Conn.assign(:session_delivery_mode, :cookie)
      |> Plug.Conn.assign(:mu_session_id, Plug.Conn.get_session(frontend_connection, :mu_session_id))
      |> Plug.Conn.assign(:mu_auth_allowed_groups, Plug.Conn.get_session(frontend_connection, :mu_auth_allowed_groups))
      |> Plug.Conn.assign(:session_allowed_groups_set_at, Plug.Conn.get_session(frontend_connection, :session_allowed_groups_set_at))
      |> Plug.Conn.assign(:session_max_expires_at, Plug.Conn.get_session(frontend_connection, :session_max_expires_at))
      |> Plug.Conn.assign(:session_last_activity_at, Plug.Conn.get_session(frontend_connection, :session_last_activity_at))

    cookie_present = Map.has_key?(frontend_connection.req_cookies, "proxy_session")
    session_empty = frontend_connection.assigns[:mu_session_id] == nil

    frontend_connection =
      if cookie_present && session_empty do
        Plug.Conn.assign(frontend_connection, :session_cookie_unreadable, true)
      else
        frontend_connection
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
