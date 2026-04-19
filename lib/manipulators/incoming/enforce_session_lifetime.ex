defmodule Manipulators.Incoming.EnforceSessionLifetime do
  @moduledoc """
  Enforces the session lifetime.  This is the maximum time the session can live and it can only be bumped by a backend header.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    now = System.os_time(:second)
    session_lifetime_expires_at = frontend_connection.assigns[:session_lifetime_expires_at]

    if session_lifetime_expires_at && session_lifetime_expires_at < now do
      {headers, frontend_connection} =
        SessionInvalidation.register(
          Application.get_env(:mu_identifier, :session_lifetime_strategy),
          frontend_connection,
          headers,
          :session_lifetime_exceeded
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
