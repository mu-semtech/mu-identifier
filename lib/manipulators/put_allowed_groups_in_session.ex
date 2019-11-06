defmodule Manipulators.PutAllowedGroupsInSession do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    authorization =
      headers
      |> List.keyfind("mu-auth-allowed-groups", 0, {nil, nil})
      |> elem(1)

    if Application.get_env(:mu_identifier, :log_outgoing_allowed_groups) ||
         Application.get_env(:mu_identifier, :log_allowed_groups) do
      IO.inspect(authorization, label: "Outgoing allowed groups")
    end

    frontend_connection =
      case authorization do
        "CLEAR" ->
          # Set CLEAR as the authorization group so we can pick it
          # up on the next request
          Plug.Conn.put_session(frontend_connection, :mu_auth_allowed_groups, authorization)

        nil ->
          frontend_connection

        _ ->
          Plug.Conn.put_session(frontend_connection, :mu_auth_allowed_groups, authorization)
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
