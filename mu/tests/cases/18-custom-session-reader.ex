defmodule Manipulators.Incoming.CustomSessionReader do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    case List.keyfind(headers, "x-custom-session-id", 0) do
      {_key, session_id} ->
        allowed_groups =
          case List.keyfind(headers, "x-custom-allowed-groups", 0) do
            {_key, groups} -> groups
            nil -> nil
          end

        # Write into the Plug session so ReadSessionFromCookie picks these up.
        frontend_connection =
          frontend_connection
          |> Plug.Conn.put_session(:mu_session_id, session_id)
          |> Plug.Conn.put_session(:mu_auth_allowed_groups, allowed_groups)

        # Remove the Authorization header so ReadSessionFromJwt does not process it.
        headers = List.keydelete(headers, "authorization", 0)

        {headers, {frontend_connection, backend_connection}}

      nil ->
        {headers, {frontend_connection, backend_connection}}
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
