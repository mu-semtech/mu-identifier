defmodule Manipulators.Incoming.AddCustomRequestHeaders do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do

    # If the admin requests a forced clearing of the mu_session_id that means it cannot come back.  We do this first and
    # we ignore other expected behaviour.  Session is gone, only audit trail available.
    frontend_connection = if SessionInvalidation.query(frontend_connection, { :admin, :force_clear_mu_session_id }) do
      SessionInvalidation.force_clear_mu_session_id(frontend_connection)
    else
      frontend_connection
    end

    # Then we handle regular session clearing, even when the session was already force-cleared
    frontend_connection = if SessionInvalidation.query(frontend_connection, { :_, :clear_mu_session_id }) do
      SessionInvalidation.clear_mu_session_id(frontend_connection)
    else
      frontend_connection
    end

    # At this point we should clear the mu-auth-allowed-groups if that hasn't been done through session clearing
    frontend_connection = cond do
      SessionInvalidation.force_cleared_mu_session_id?(frontend_connection) -> frontend_connection
      SessionInvalidation.cleared_mu_session_id?(frontend_connection) -> frontend_connection
      SessionInvalidation.query(frontend_connection, { :_, :clear_mu_auth_allowed_groups }) ->
        SessionInvalidation.clear_mu_auth_allowed_groups(frontend_connection)
      true -> frontend_connection
    end

    # With the state of the assigns updated, we'll handle the unauthorized case based on what we know at that point.
    # The backend can still recover a previous mu-session-id and we'll leave it be (always assigning a new mu-session-id
    # to the backend request) until the backend chooses to reinstate or clear the session.  reinstating will by default
    # reinstate the old mu-session-id but it could request to instate the new mu-session-id instead through a different
    # header TODO: support the different header in the response.
    # We look at the various cases separately here and then start merging them
    frontend_connection = cond do
      # We don't care specifically for force_cleared_mu_session_id as that's a nuclear option and we just want the
      # session gone When the mu-session-id was cleared, we will pretend to have the new mu-session-id, but a backend
      # could act on the previous-mu-session-id instead and recover with Mu-Reinstate-Session: previous to recover that
      # session id with future extensions.

      # This is only special in the processing of the other direction
      SessionInvalidation.query(frontend_connection, { :_, :unauthorized }) ->
        SessionInvalidation.unauthorize(frontend_connection)
      # SessionInvalidation.force_cleared_mu_session_id?(frontend_connection) ->
      #   # like it didn't happen
      #   frontend_connection
      # SessionInvalidation.query(frontend_connection, { :_, :clear_mu_auth_allowed_groups }) ->
      #   # like it didn't happen
      true ->
        frontend_connection
    end

    # NOTE: both mu-auth-allowed-groups as well as revoked_mu_auth_allowed_groups are translated through CLEAR etc but only if their corresponding mu-session-id contains a value (otherwise they're presumed to be empty).
    
    # -- write out the headers -- #
    # All assigns should now be set, it's merely setting the header when it's available.

    new_headers = [
      { "mu-session-id", frontend_connection.assigns[:mu_session_id] },
      { "mu-auth-allowed-groups", derive_effective_mu_auth_allowed_groups( frontend_connection ) },
      { "cleared-mu-session-id", frontend_connection.assigns[:cleared_mu_session_id] },
      { "cleared-mu-auth-allowed-groups", frontend_connection.assigns[:cleared_mu_auth_allowed_groups] },
      { "force-cleared-mu-session-id", frontend_connection.assigns[:force_cleared_mu_session_id] },
      { "force-cleared-mu-auth-allowed-groups", frontend_connection.assigns[:force_cleared_mu_auth_allowed_groups] },
      { "user-cleared-mu-session-id", frontend_connection.assigns[:user_cleared_mu_session_id] },
      { "user-cleared-mu-auth-allowed-groups", frontend_connection.assigns[:user_cleared_mu_auth_allowed_groups] },
      { "revoked-mu-session-id", frontend_connection.assigns[:revoked_mu_session_id] },
      { "revoked-mu-auth-allowed-groups", derive_effective_revoked_mu_auth_allowed_groups( frontend_connection ) },
      { "mu-unauthorized", (SessionInvalidation.unauthorized?( frontend_connection ) && "true") || nil }
    ]
      |> Enum.filter( fn ({_header, value}) -> value != nil end )
    

    { new_headers ++ headers,
      {frontend_connection, backend_connection} }
  end
  
  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip

  defp derive_effective_revoked_mu_auth_allowed_groups( connection ) do
    if connection.assigns[:revoked_mu_session_id] do
      groups = connection.assigns[:revoked_mu_auth_allowed_groups]

      case groups do
        "CLEAR" -> nil
        nil -> Application.get_env(:mu_identifier, :default_mu_auth_allowed_groups_header)
        _ -> groups
      end
    else
      nil
    end
  end

  defp derive_effective_mu_auth_allowed_groups( connection ) do
    groups = connection.assigns[:mu_auth_allowed_groups]

    case groups do
      "CLEAR" -> nil
      nil -> Application.get_env(:mu_identifier, :default_mu_auth_allowed_groups_header)
      _ -> groups
    end
  end
end
