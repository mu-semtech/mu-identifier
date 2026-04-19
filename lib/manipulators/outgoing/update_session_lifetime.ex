defmodule Manipulators.Outgoing.UpdateSessionLifetime do
  @moduledoc """
  Manages the session's max age by reading `Mu-Session-Valid-Until` from the
  backend response into the session and reporting the remaining time to the
  client via `Mu-Session-Lifetime-Expires-In`.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    # TODO: Perhaps we should (optionally?) warn when we are hitting the session lifetime AND there's no strategy defined to handle that.

    # TODO: Verify we are setting the lifetime in the session

    headers = List.keydelete(headers, "mu-session-lifetime-expires-in", 0)

    now = System.os_time(:second)
    was_unauthorized = SessionInvalidation.query( frontend_connection, { :_, :unauthorized } )
    reinstate_revoked_session = frontend_connection.assigns[:reinstate_revoked_session] == true

    default_valid_until =
      case Application.get_env(:mu_identifier, :default_session_lifetime_seconds) do
        nil -> nil
        seconds -> now + seconds
      end

    original_valid_until = frontend_connection.assigns[:session_lifetime_expires_at]
    revoked_for_session_lifetime = SessionInvalidation.query( frontend_connection, { :session_lifetime_exceeded, :unauthorized } )

    backend_supplied_valid_until =
      case List.keyfind(headers, "mu-session-valid-until", 0) do
        { _key, value } ->
          String.to_integer(value)
        nil ->
          false
      end

    valid_until =
      cond do
        backend_supplied_valid_until ->
          # Backend always wins
          backend_supplied_valid_until
        reinstate_revoked_session
        && revoked_for_session_lifetime
        && default_valid_until ->
          # Asked to set it back up
          default_valid_until
        original_valid_until ->
          original_valid_until
        true -> nil
      end

    frontend_connection = Plug.Conn.assign( frontend_connection, :session_lifetime_expires_at, valid_until )
    headers = if valid_until do
        [ {"mu-session-lifetime-expires-in", Integer.to_string(valid_until - now)} | headers ]
      else
        headers
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
