defmodule Manipulators.Outgoing.UpdateSessionKeepalive do
  @moduledoc """
  Manages the session's idle timeout by recording the current time as the last
  activity and reporting the remaining idle window to the client via
  `Mu-Session-Keepalive-Expires-In`.  Only active when `SESSION_KEEPALIVE_SECONDS`
  is configured.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    now = System.os_time(:second)
    keepalive_seconds = Application.get_env(:mu_identifier, :session_keepalive_seconds)
    headers =
      headers
      |> List.keydelete("mu-session-keepalive-expires-in", 0)

    was_unauthorized = SessionInvalidation.query( frontend_connection, { :_, :unauthorized } )
    reinstate_revoked_session = frontend_connection.assigns[:reinstate_revoked_session] == true

    cond do
      was_unauthorized
      && !reinstate_revoked_session ->
        { headers, { frontend_connection, backend_connection } }
      keepalive_seconds ->
        frontend_connection = Plug.Conn.assign(frontend_connection, :session_last_activity_at, now)
        headers = [{"mu-session-keepalive-expires-in", Integer.to_string(keepalive_seconds)} | headers]
        { headers, { frontend_connection, backend_connection } }
      true ->
        { headers, { frontend_connection, backend_connection } }
      end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
