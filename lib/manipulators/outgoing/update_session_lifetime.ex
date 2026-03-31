defmodule Manipulators.Outgoing.UpdateSessionLifetime do
  @moduledoc """
  Manages the session's max age by reading `Mu-Session-Valid-Until` from the
  backend response into the session and reporting the remaining time to the
  client via `Mu-Session-Lifetime-Expires-In`.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    skip_session_write =
      frontend_connection.assigns[:mu_unauthorized] == true &&
        frontend_connection.assigns[:reinstate_revoked_session] != true

    if skip_session_write do
      {headers, {frontend_connection, backend_connection}}
    else
      now = System.os_time(:second)

      default_valid_until =
        case Application.get_env(:mu_identifier, :default_session_max_age_seconds) do
          nil -> nil
          seconds -> now + seconds
        end

      original_valid_until = frontend_connection.assigns[:session_max_expires_at]
      reinstating = frontend_connection.assigns[:reinstate_revoked_session]
      session_revocation_reasons = frontend_connection.assigns[:session_revocation_reasons] || []

      valid_until =
        case List.keyfind(headers, "mu-session-valid-until", 0) do
          {_key, value} ->
            String.to_integer(value)

          nil ->
            if reinstating && :session_max_age_exceeded in session_revocation_reasons
                 && original_valid_until && default_valid_until do
              max(original_valid_until, default_valid_until)
            else
              original_valid_until || default_valid_until
            end
        end

      frontend_connection = Plug.Conn.assign(frontend_connection, :session_max_expires_at, valid_until)

      headers =
        case valid_until do
          nil -> headers
          _ -> [{"mu-session-lifetime-expires-in", Integer.to_string(valid_until - now)} | headers]
        end

      {headers, {frontend_connection, backend_connection}}
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
