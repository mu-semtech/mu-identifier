defmodule Manipulators.Incoming.ReadSessionFromCookie do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    cond do
      match?({_key, "Bearer " <> _token},List.keyfind(headers, "authorization", 0)) ->
        # we have received a JWT token, stop further processing
        { headers, { frontend_connection, backend_connection } }
      cookie_present?(frontend_connection) && !cookie_has_session_id?(frontend_connection) ->
        if Application.get_env(:mu_identifier, :debug_session) do
          IO.puts("Session cookie present but could not be decoded or did not contain session_id")
        end
        IO.puts("Session cookie could not be decoded or did not contain session.")
        frontend_connection = Plug.Conn.assign(frontend_connection, :session_cookie_unreadable, true)
        { headers, { frontend_connection, backend_connection } }
      true ->
        session_id = Plug.Conn.get_session(frontend_connection, :mu_session_id)
        if Application.get_env(:mu_identifier, :debug_session) do
          IO.inspect(session_id, label: "Session id from cookie")
        end

        frontend_connection =
          frontend_connection
          |> Plug.Conn.assign(:session_delivery_mode, :cookie)
          |> Plug.Conn.assign(:mu_session_id, session_id)
          |> Plug.Conn.assign(:mu_auth_allowed_groups, Plug.Conn.get_session(frontend_connection, :mu_auth_allowed_groups))
          |> Plug.Conn.assign(:session_allowed_groups_set_at, Plug.Conn.get_session(frontend_connection, :session_allowed_groups_set_at))
          |> Plug.Conn.assign(:session_lifetime_expires_at, Plug.Conn.get_session(frontend_connection, :session_lifetime_expires_at))
          |> Plug.Conn.assign(:session_last_activity_at, Plug.Conn.get_session(frontend_connection, :session_last_activity_at))

        frontend_connection =
          Plug.Conn.assign(frontend_connection, :previous_session_state, %{
            # same state as for jwt token
            session_delivery_mode: frontend_connection.assigns[:session_delivery_mode],
            mu_session_id: frontend_connection.assigns[:mu_session_id],
            mu_auth_allowed_groups: frontend_connection.assigns[:mu_auth_allowed_groups],
            session_allowed_groups_set_at: frontend_connection.assigns[:session_allowed_groups_set_at],
            session_lifetime_expires_at: frontend_connection.assigns[:session_lifetime_expires_at],
            session_last_activity_at: frontend_connection.assigns[:session_last_activity_at]
          })
        { headers, { frontend_connection, backend_connection } }
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip

  defp cookie_present?( frontend_connection ) do
    Map.has_key?(frontend_connection.req_cookies, "proxy_session")
  end

  defp cookie_has_session_id?( frontend_connection ) do
    Plug.Conn.get_session(frontend_connection, :mu_session_id) != nil
  end
end
