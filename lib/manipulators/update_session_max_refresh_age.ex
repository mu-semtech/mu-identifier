defmodule Manipulators.UpdateSessionMaxRefreshAge do
  @moduledoc """
  Manages the session's idle timeout by recording the current time as the last
  activity and reporting the remaining idle window to the client via
  `Mu-Session-Refresh-Expires-In`.  Only active when `SESSION_MAX_REFRESH_AGE_SECONDS`
  is configured.

  NOTE: This manipulator reads a backend header and writes a client header and
  must run before `ClearMuInternalKeys`.  Either this could be split or
  `ClearMuInternalKeys` could be.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    case Application.get_env(:mu_identifier, :session_max_refresh_age_seconds) do
      nil ->
        {headers, {frontend_connection, backend_connection}}

      max_refresh ->
        now = System.os_time(:second)

        frontend_connection =
          frontend_connection
          |> Plug.Conn.put_session(:session_last_activity_at, now)
          |> Plug.Conn.assign(:session_last_activity_at, now)

        headers = [{"mu-session-refresh-expires-in", Integer.to_string(max_refresh)} | headers]

        {headers, {frontend_connection, backend_connection}}
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
