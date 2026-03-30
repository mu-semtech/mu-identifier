defmodule Manipulators.EnforceSessionKeepalive do
  @moduledoc """
  Enforces the session idle-timeout policy.  When the session has been idle for
  longer than `SESSION_MAX_REFRESH_AGE_SECONDS`, the configured
  `SESSION_MAX_REFRESH_AGE_STRATEGY` is applied.

  Supported strategies: see `SessionStrategy`.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    now = System.os_time(:second)
    max_refresh_age_seconds = Application.get_env(:mu_identifier, :session_max_refresh_age_seconds)
    session_last_activity_at = frontend_connection.assigns[:session_last_activity_at]

    if max_refresh_age_seconds && session_last_activity_at &&
         now - session_last_activity_at > max_refresh_age_seconds do
      {headers, frontend_connection} =
        SessionExpiration.handle(
          Application.get_env(:mu_identifier, :session_max_refresh_age_strategy),
          frontend_connection,
          headers,
          :session_max_refresh_age_exceeded
        )

      {headers, {frontend_connection, backend_connection}}
    else
      {headers, {frontend_connection, backend_connection}}
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
