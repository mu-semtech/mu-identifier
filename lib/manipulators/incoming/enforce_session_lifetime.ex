defmodule Manipulators.Incoming.EnforceSessionLifetime do
  @moduledoc """
  Enforces the session max-age policy.  When the session has exceeded its
  maximum age, the configured `SESSION_MAX_AGE_STRATEGY` is applied.

  Supported strategies: see `SessionStrategy`.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    now = System.os_time(:second)
    session_max_expires_at = frontend_connection.assigns[:session_max_expires_at]

    if session_max_expires_at && session_max_expires_at < now do
      {headers, frontend_connection} =
        SessionExpiration.handle(
          Application.get_env(:mu_identifier, :session_max_age_strategy),
          frontend_connection,
          headers,
          :session_max_age_exceeded
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
