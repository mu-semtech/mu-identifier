defmodule Manipulators.ReadSessionFromCookie do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    if Application.get_env(:mu_identifier, :debug_session) do
      IO.inspect(Plug.Conn.get_session(frontend_connection, :proxy_user_id), label: "Session id from cookie")
    end

    frontend_connection = Plug.Conn.assign(frontend_connection, :session_mode, :cookie)

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
