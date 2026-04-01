defmodule Manipulators.Outgoing.WriteSessionCookie do
  @moduledoc """
  Flushes session assigns to the cookie session when the delivery mode is `:cookie`.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    skip_session_write =
      frontend_connection.assigns[:mu_unauthorized] == true &&
        frontend_connection.assigns[:reinstate_revoked_session] != true

    frontend_connection =
      if frontend_connection.assigns[:session_delivery_mode] == :cookie && !skip_session_write do
        previous = frontend_connection.assigns[:previous_session_state]
        current = %{
          session_delivery_mode: frontend_connection.assigns[:session_delivery_mode],
          mu_session_id: frontend_connection.assigns[:mu_session_id],
          mu_auth_allowed_groups: frontend_connection.assigns[:mu_auth_allowed_groups],
          session_allowed_groups_set_at: frontend_connection.assigns[:session_allowed_groups_set_at],
          session_lifetime_expires_at: frontend_connection.assigns[:session_lifetime_expires_at],
          session_last_activity_at: frontend_connection.assigns[:session_last_activity_at]
        }

        if current != previous do
          # Plug.Conn.put_session/3 forces the cookie to be written so we check
          # before writing.
          # See: https://hexdocs.pm/plug/Plug.Conn.html#put_session/3
          frontend_connection
          |> put_or_delete(:mu_session_id, current.mu_session_id)
          |> put_or_delete(:mu_auth_allowed_groups, current.mu_auth_allowed_groups)
          |> put_or_delete(:session_allowed_groups_set_at, current.session_allowed_groups_set_at)
          |> put_or_delete(:session_lifetime_expires_at, current.session_lifetime_expires_at)
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
