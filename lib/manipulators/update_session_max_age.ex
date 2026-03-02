defmodule Manipulators.UpdateSessionMaxAge do
  @moduledoc """
  Manages the session's max age by reading `Mu-Session-Valid-Until` from the
  backend response into the session and reporting the remaining time to the
  client via `Mu-Session-Expires-In`.

  NOTE: This manipulator reads a backend header and writes a client header and
  must run before `ClearMuInternalKeys`.  Either this could be split or
  `ClearMuInternalKeys` could be.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    valid_until =
      case List.keyfind(headers, "mu-session-valid-until", 0) do
        {_key, value} ->
          String.to_integer(value)

        nil ->
          frontend_connection.assigns[:session_valid_until] ||
            case Application.get_env(:mu_identifier, :default_session_max_age_seconds) do
              nil -> nil
              seconds -> System.os_time(:second) + seconds
            end
      end

    frontend_connection =
      frontend_connection
      |> Plug.Conn.put_session(:session_valid_until, valid_until)
      |> Plug.Conn.assign(:session_valid_until, valid_until)

    headers =
      case valid_until do
        nil -> headers
        _ -> [{"mu-session-expires-in", Integer.to_string(valid_until - System.os_time(:second))} | headers]
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
