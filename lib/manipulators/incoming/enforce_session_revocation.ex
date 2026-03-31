defmodule Manipulators.Incoming.EnforceSessionRevocation do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    mu_session_id = frontend_connection.assigns[:mu_session_id]
    allowed_groups_string = frontend_connection.assigns[:mu_auth_allowed_groups]
    session_allowed_groups_set_at = frontend_connection.assigns[:session_allowed_groups_set_at]

    {headers, frontend_connection} =
      case mu_session_id && RevocationStore.get_session_id_revocation(mu_session_id) do
        nil -> {headers, frontend_connection}
        strategy -> SessionExpiration.handle(strategy, frontend_connection, headers, :session_id_revoked)
      end

    {headers, frontend_connection} =
      case allowed_groups_string && RevocationStore.get_allowed_groups_revocation(allowed_groups_string) do
        {revoked_at, strategy} when revoked_at >= session_allowed_groups_set_at ->
          SessionExpiration.handle(strategy, frontend_connection, headers, :allowed_groups_revoked)

        _ ->
          {headers, frontend_connection}
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
