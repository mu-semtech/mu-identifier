defmodule Manipulators.EnforceSessionRevocation do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    mu_session_id = frontend_connection.assigns[:mu_session_id]
    allowed_groups_string = frontend_connection.assigns[:mu_auth_allowed_groups]
    groups_issued_at = frontend_connection.assigns[:groups_issued_at]

    {headers, frontend_connection} =
      case mu_session_id && SessionRevocation.mu_session_id_revoked?(mu_session_id) do
        nil -> {headers, frontend_connection}
        strategy -> SessionExpiration.handle(strategy, frontend_connection, headers)
      end

    {headers, frontend_connection} =
      case allowed_groups_string && SessionRevocation.allowed_groups_string_revoked?(allowed_groups_string) do
        {revoked_at, strategy} when revoked_at > groups_issued_at ->
          SessionExpiration.handle(strategy, frontend_connection, headers)

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
