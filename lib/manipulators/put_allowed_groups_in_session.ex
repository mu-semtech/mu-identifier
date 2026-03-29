defmodule Manipulators.PutAllowedGroupsInSession do
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
      session_revocation_reasons = frontend_connection.assigns[:session_revocation_reasons] || []

      # Refresh timestamp on reinstatement so revocation check no longer triggers.
      frontend_connection =
        if frontend_connection.assigns[:reinstate_revoked_session]
             && :allowed_groups_revoked in session_revocation_reasons do
          Plug.Conn.assign(frontend_connection, :session_allowed_groups_set_at, now)
        else
          frontend_connection
        end

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
            frontend_connection
            |> Plug.Conn.assign(:mu_auth_allowed_groups, authorization)
            |> Plug.Conn.assign(:session_allowed_groups_set_at, now)

          nil ->
            frontend_connection

          _ ->
            frontend_connection
            |> Plug.Conn.assign(:mu_auth_allowed_groups, authorization)
            |> Plug.Conn.assign(:session_allowed_groups_set_at, now)
        end

      {headers, {frontend_connection, backend_connection}}
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
