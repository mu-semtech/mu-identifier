defmodule Manipulators.EnforceSessionRevocation do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    mu_session_id = Plug.Conn.get_session(frontend_connection, :proxy_user_id)
    allowed_groups_string = Plug.Conn.get_session(frontend_connection, :mu_auth_allowed_groups)
    groups_issued_at = Plug.Conn.get_session(frontend_connection, :groups_issued_at)

    {headers, frontend_connection} =
      case mu_session_id && SessionRevocation.mu_session_id_revoked?(mu_session_id) do
        nil -> {headers, frontend_connection}
        strategy -> SessionStrategy.apply(strategy, frontend_connection, headers)
      end

    {headers, frontend_connection} =
      case allowed_groups_string && SessionRevocation.allowed_groups_string_revoked?(allowed_groups_string) do
        {revoked_at, strategy} when revoked_at > groups_issued_at ->
          SessionStrategy.apply(strategy, frontend_connection, headers)

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
