defmodule Manipulators.WriteSessionCookie do
  @moduledoc """
  Flushes session assigns to the cookie session when the delivery mode is `:cookie`.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection})
      when frontend_connection.assigns.mu_auth_unauthorized == true and
             frontend_connection.assigns.reinstate_revoked_session != true do
    {headers, {frontend_connection, backend_connection}}
  end

  def headers(headers, {frontend_connection, backend_connection}) do
    frontend_connection =
      if frontend_connection.assigns[:session_delivery_mode] == :cookie do
        previous = frontend_connection.assigns[:mu_previous_session_state]
        current = %{
          session_delivery_mode: frontend_connection.assigns[:session_delivery_mode],
          mu_session_id: frontend_connection.assigns[:mu_session_id],
          mu_auth_allowed_groups: frontend_connection.assigns[:mu_auth_allowed_groups],
          groups_issued_at: frontend_connection.assigns[:groups_issued_at],
          session_valid_until: frontend_connection.assigns[:session_valid_until],
          session_last_activity_at: frontend_connection.assigns[:session_last_activity_at]
        }

        if current != previous do
          # Plug.Conn.put_session/3 forces the cookie to be written so we check
          # before writing.
          # See: https://hexdocs.pm/plug/Plug.Conn.html#put_session/3
          frontend_connection
          |> put_or_delete(:proxy_user_id, current.mu_session_id)
          |> put_or_delete(:mu_auth_allowed_groups, current.mu_auth_allowed_groups)
          |> put_or_delete(:groups_issued_at, current.groups_issued_at)
          |> put_or_delete(:session_valid_until, current.session_valid_until)
          |> put_or_delete(:session_last_activity_at, current.session_last_activity_at)
        else
          frontend_connection
        end
      else
        frontend_connection
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip

  defp put_or_delete(conn, key, nil), do: Plug.Conn.delete_session(conn, key)
  defp put_or_delete(conn, key, value), do: Plug.Conn.put_session(conn, key, value)
end
