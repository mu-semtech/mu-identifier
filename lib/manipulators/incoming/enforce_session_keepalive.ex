defmodule Manipulators.Incoming.EnforceSessionKeepalive do
  @moduledoc """
  Enforces the session idle-timeout policy.  When the session has been idle for
  longer than `SESSION_KEEPALIVE_SECONDS`, the configured
  `SESSION_KEEPALIVE_STRATEGY` is applied.

  Supported strategies: see `SessionStrategy`.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    now = System.os_time(:second)
    keepalive_seconds = Application.get_env(:mu_identifier, :session_keepalive_seconds)
    session_last_activity_at = frontend_connection.assigns[:session_last_activity_at]

    if keepalive_seconds && session_last_activity_at &&
         now - session_last_activity_at > keepalive_seconds do
      {headers, frontend_connection} =
        SessionInvalidation.register(
          Application.get_env(:mu_identifier, :session_keepalive_strategy),
          frontend_connection,
          headers,
          :session_keepalive_exceeded
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
