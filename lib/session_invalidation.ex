defmodule SessionInvalidation do
  @moduledoc """
  Handles session invalidation strategies shared across session enforcement manipulators.
  """

  def register(connection, nil, _), do: connection

  def register(frontend_connection, strategy, reason) do
    IO.inspect( {strategy, reason}, label: "Registering in SessionInvalidation" )
    Plug.Conn.assign(
      frontend_connection,
      :invalidation_strategies,
      [{reason, strategy} | frontend_connection.assigns[:invalidation_strategies] || []]
    )
  end

  def register(strategy, connection, headers, reason) do
    { headers, register( connection, strategy, reason ) }
  end

  def query(connection, filter) do
    query_filter(  connection.assigns[:invalidation_strategies], filter )
  end

  def query_filter(nil, _), do: false
  def query_filter([], _), do: false
  def query_filter(_strategies,{:_,:_}), do: true
  def query_filter(strategies,{:_,strategy}) do
    Enum.any?(strategies, &match?({_,^strategy}, &1) )
  end
  def query_filter(strategies,{reason,:_}) do
    Enum.any?(strategies, &match?({^reason,_}, &1) )
  end
  def query_filter(strategies,{reason, strategy}) do
    Enum.any?(strategies, &match?({^reason,^strategy}, &1) )
  end

  @doc """
  Clears the mu-session-id in a way that following processors will not be able to reuse the results.  It is logged to
  the backend through headers for auditing purposes but the session cannot be restored this way.
  """
  def force_clear_mu_session_id( connection ) do
    # 1. store the old mu-session-id in force-cleared-mu-session-id assigns
    # 2. set the new mu-session-id in mu-session-id assigns (note that this may still arrive in the backend)
    # 3. move the mu-auth-allowed-groups to force-cleared-mu-auth-allowed-groups assigns
    # 4. mark the session as cleared

    connection
    |> Plug.Conn.assign(:force_cleared_mu_session_id, connection.assigns[:mu_session_id])
    |> Plug.Conn.assign(:force_cleared_mu_auth_allowed_groups, connection.assigns[:mu_auth_allowed_groups])
    |> clear_session_without_audit_headers()
    |> Plug.Conn.assign(:force_cleared_session, true)
  end

  def force_cleared_mu_session_id?(connection) do
    connection.assigns[:force_cleared_session] != nil
  end

  def clear_mu_auth_allowed_groups( connection ) do
    # 1. store the old mu-auth-allowed-groups in previous-mu-auth-allowed-groups assigns
    # 2. move the old mu-auth-allowed-groups to previous-mu-auth-allowed-groups assigns
    # 3. mark mu-auth-allowed-groups as cleared

    cond do
      SessionInvalidation.force_cleared_mu_session_id?(connection) -> connection
      SessionInvalidation.cleared_mu_session_id?(connection) -> connection
      true ->
        connection
        |> Plug.Conn.assign(:cleared_mu_auth_allowed_groups, connection.assigns[:mu_auth_allowed_groups])
        |> Plug.Conn.assign(:mu_auth_allowed_groups, nil)
        |> Plug.Conn.assign(:session_allowed_groups_set_at, nil)
    end
  end

  def cleared_mu_auth_allowed_groups?(connection) do
    connection.assigns[:cleared_session] != nil
  end

  @doc """
  Clears the mu-session-id in a way through which restore will be able to reset it from the backend.
  """
  def clear_mu_session_id( connection ) do
    # 1. store the old mu-session-id in cleared-mu-session-id assigns
    # 2. set the new mu-session-id in mu-session-id assigns (note that this may still arrive in the backend)
    # 3. move the mu-auth-allowed-groups to cleared-mu-auth-allowed-groups
    # 4. mark the session as cleared

    # NOTE: should this session also be unauthorized, recovering the session will set back the previous-mu-session-id unlike with force_clear_mu_session_id.
    connection
    |> Plug.Conn.assign(:cleared_mu_session_id, connection.assigns[:mu_session_id])
    |> Plug.Conn.assign(:cleared_mu_auth_allowed_groups, connection.assigns[:mu_auth_allowed_groups])
    |> clear_session_without_audit_headers()
    |> Plug.Conn.assign(:cleared_session, true)
  end

  def cleared_mu_session_id?(connection) do
    connection.assigns[:cleared_session] != nil
  end

  @doc """
  Unauthorizes the connection such that the backend will have to handle the session-id and mu-auth-allowed-groups differently.
  """
  def unauthorize( connection ) do
    mu_session_id = if SessionInvalidation.cleared_mu_session_id?( connection ) do
      connection.assigns[:cleared_mu_session_id]
    else
      connection.assigns[:mu_session_id]
    end

    mu_auth_allowed_groups = cond do
      SessionInvalidation.cleared_mu_auth_allowed_groups?( connection ) ->
        connection.assigns[:cleared_mu_auth_allowed_groups]
      SessionInvalidation.cleared_mu_session_id?( connection ) ->
        connection.assigns[:cleared_mu_auth_allowed_groups]
      true ->
        connection.assigns[:mu_auth_allowed_groups]
    end

    connection
    |> Plug.Conn.assign(:revoked_mu_session_id, mu_session_id)
    |> Plug.Conn.assign(:revoked_mu_auth_allowed_groups, mu_auth_allowed_groups)
    |> Plug.Conn.assign(:mu_session_id, nil)
    |> Plug.Conn.assign(:mu_auth_allowed_groups, nil)
    |> Plug.Conn.assign(:unauthorized_session, true)
  end

  def unauthorized?( connection ) do
    connection.assigns[:unauthorized_session] != nil
  end

  @doc "Clears the session but does not set the corresponding audit headers."
  def clear_session_without_audit_headers(connection) do
    connection
    |> Plug.Conn.assign(:mu_session_id, Manipulators.Incoming.EnsureUserSession.new_session_uri())
    |> Plug.Conn.assign(:mu_auth_allowed_groups, nil)
    |> Plug.Conn.assign(:session_allowed_groups_set_at, nil)
    |> Plug.Conn.assign(:session_lifetime_expires_at, nil)
    |> Plug.Conn.assign(:session_last_activity_at, nil)
  end

  @doc "Fully resets the session"
  def reset_session(connection) do
    connection
    |> clear_session_without_audit_headers
    |> Plug.Conn.assign(:jwt_token_unreadable, nil)
    |> Plug.Conn.assign(:previous_session_state, nil)
    |> Plug.Conn.assign(:session_cookie_unreadable, nil)
    |> Plug.Conn.assign(:session_delivery_mode, :cookie)
    |> Plug.Conn.assign(:session_cookie_unreadable, nil)
    |> Plug.Conn.assign(:session_revocation_reasons, [])
  end

end
