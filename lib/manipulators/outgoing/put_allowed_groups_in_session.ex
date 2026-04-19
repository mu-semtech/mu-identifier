defmodule Manipulators.Outgoing.PutAllowedGroupsInSession do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    # We have to put the right allowed groups in the session based on:
    # - what the backend returned
    # - whether the session was revoked
    # - whether the session is being reinstated
    # - what the groups were as we sent them to the backend

    now = System.os_time(:second)
    was_unauthorized = SessionInvalidation.query( frontend_connection, { :_, :unauthorized } )
    reinstate_revoked_session = frontend_connection.assigns[:reinstate_revoked_session] == true

    backend_allowed_groups =
      headers
      |> List.keyfind("mu-auth-allowed-groups", 0, {nil, nil})
      |> elem(1)

    frontend_connection =
      cond do
        !was_unauthorized
        && backend_allowed_groups != nil ->
          frontend_connection
          |> Plug.Conn.assign(:mu_auth_allowed_groups, backend_allowed_groups)
          |> Plug.Conn.assign(:session_allowed_groups_set_at, now)

        !was_unauthorized
        && backend_allowed_groups == nil ->
          # We should keep the original allowed groups which are already set
          frontend_connection

        was_unauthorized
        && !reinstate_revoked_session
        && backend_allowed_groups != nil ->
          # If we receive new mu-auth-allowed-groups, we'll set those and we will reset the timer (this might repair the session)
          frontend_connection
          |> Plug.Conn.assign(:mu_auth_allowed_groups, backend_allowed_groups)
          |> Plug.Conn.assign(:session_allowed_groups_set_at, now)

        was_unauthorized
        && !reinstate_revoked_session
        && backend_allowed_groups == nil ->
          # If we should otherwise keep the session revoked, we'll put back the revoked mu_auth_allowed_groups
          revoked_mu_auth_allowed_groups = frontend_connection.assigns[:revoked_mu_auth_allowed_groups]

          frontend_connection
          |> Plug.Conn.assign(:mu_auth_allowed_groups, revoked_mu_auth_allowed_groups)

        was_unauthorized
        && reinstate_revoked_session
        && backend_allowed_groups == nil ->
          # Reinstating the session when a backend doesn't set anything means we'll put back the revoked
          # mu_auth_allowed_groups andreset the timer

          revoked_mu_auth_allowed_groups = frontend_connection.assigns[:revoked_mu_auth_allowed_groups]

          frontend_connection
          |> Plug.Conn.assign(:mu_auth_allowed_groups, revoked_mu_auth_allowed_groups)
          |> Plug.Conn.assign(:session_allowed_groups_set_at, now)

        was_unauthorized
        && reinstate_revoked_session
        && backend_allowed_groups != nil ->
          # Reinstating the session when the backend has provided new mu-auth-allowed-groups means we'll use those
          # instead.

          # Note: we could simplify computation here if needed but having the options laid out is easier to reason on as
          # a human.

          frontend_connection
          |> Plug.Conn.assign(:mu_auth_allowed_groups, backend_allowed_groups)
          |> Plug.Conn.assign(:session_allowed_groups_set_at, now)

        true ->
          # We should keep the original allowed groups which are already set
          IO.puts( "WARNING: Unexpectedly fell through case for setting allowed groups, not changing connection." )
          frontend_connection
      end

    if Application.get_env(:mu_identifier, :log_outgoing_allowed_groups)
       || Application.get_env(:mu_identifier, :log_allowed_groups)
    do
      IO.inspect(frontend_connection.assigns[:mu_auth_allowed_groups], label: "Outgoing allowed groups")
    end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip

end
