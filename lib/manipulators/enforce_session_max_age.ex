defmodule Manipulators.EnforceSessionMaxAge do
  @moduledoc """
  Enforces the session max-age policy.  When the session has exceeded its
  maximum age, the configured `SESSION_MAX_AGE_STRATEGY` is applied.

  Supported strategies: see `SessionStrategy`.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    now = System.os_time(:second)
    session_valid_until = frontend_connection.assigns[:session_valid_until]

    {headers, frontend_connection} =
      if session_valid_until && session_valid_until < now do
        SessionStrategy.apply(
          Application.get_env(:mu_identifier, :session_max_age_strategy),
          frontend_connection,
          headers
        )
      else
        {headers, frontend_connection}
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
