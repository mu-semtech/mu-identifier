defmodule Manipulators.ReadSessionFromJwt do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    case List.keytake(headers, "authorization", 0) do
      {{_key, "Bearer " <> token}, remaining_headers} ->
        case JwtToken.decode(token) do
          {:ok, {public_claims, private_claims}} ->
            session_id = Map.get(private_claims, "session_id")
            expires_at = Map.get(public_claims, "exp")

            if Application.get_env(:mu_identifier, :debug_session) do
              IO.inspect(session_id, label: "Session id from JWT")
              IO.inspect(expires_at, label: "Session valid until from JWT")
            end

            frontend_connection =
              frontend_connection
              |> Plug.Conn.assign(:session_delivery_mode, :jwt_header)
              |> Plug.Conn.assign(:mu_session_id, session_id)
              |> Plug.Conn.assign(:mu_auth_allowed_groups, Map.get(private_claims, "allowed_groups"))
              |> Plug.Conn.assign(:session_allowed_groups_set_at, Map.get(private_claims, "allowed_groups_set_at"))
              |> Plug.Conn.assign(:session_max_expires_at, expires_at)
              |> Plug.Conn.assign(:session_last_activity_at, Map.get(private_claims, "last_activity_at"))

            {remaining_headers, {frontend_connection, backend_connection}}

          {:error, _} ->
            frontend_connection = Plug.Conn.assign(frontend_connection, :jwt_token_unreadable, true)
            {remaining_headers, {frontend_connection, backend_connection}}
        end

      _ ->
        {headers, {frontend_connection, backend_connection}}
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
