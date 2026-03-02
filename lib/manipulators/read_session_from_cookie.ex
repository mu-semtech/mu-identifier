defmodule Manipulators.ReadSessionFromCookie do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    if Application.get_env(:mu_identifier, :debug_session) do
      IO.inspect(Plug.Conn.get_session(frontend_connection, :proxy_user_id), label: "Session id from cookie")
    end

    frontend_connection =
      frontend_connection
      |> Plug.Conn.assign(:session_delivery_mode, :cookie)
      |> Plug.Conn.assign(:session_valid_until, Plug.Conn.get_session(frontend_connection, :session_valid_until))

    frontend_connection =
      if Application.get_env(:mu_identifier, :session_max_refresh_age_seconds) do
        Plug.Conn.assign(frontend_connection, :session_last_activity_at, Plug.Conn.get_session(frontend_connection, :session_last_activity_at))
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
