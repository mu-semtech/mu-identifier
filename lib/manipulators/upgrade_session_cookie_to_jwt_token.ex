defmodule Manipulators.UpgradeSessionCookieToJwtToken do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    headers =
      if frontend_connection.assigns[:emit_jwt] do
        expires_at = frontend_connection.assigns[:session_valid_until]
        mu_session_id = Plug.Conn.get_session(frontend_connection, :proxy_user_id)
        allowed_groups = Plug.Conn.get_session(frontend_connection, :mu_auth_allowed_groups)
        groups_issued_at = Plug.Conn.get_session(frontend_connection, :groups_issued_at)

        private =
          %{"session_id" => mu_session_id}
          |> maybe_put("allowed_groups", allowed_groups)
          |> maybe_put("allowed_groups_set_at", groups_issued_at)

        [{"mu-auth-token", JwtToken.encode(expires_at, private)} | headers]
      else
        headers
      end

    frontend_connection =
      if frontend_connection.assigns[:session_delivery_mode] == :jwt_header do
        Plug.Conn.configure_session(frontend_connection, drop: true)
      else
        frontend_connection
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
