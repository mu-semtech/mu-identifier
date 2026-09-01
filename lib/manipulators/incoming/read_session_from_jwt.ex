defmodule Manipulators.Incoming.ReadSessionFromJwt do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {%{assigns: %{skip_jwt_session_reading: true}}, _} = connections) do
    {headers, connections}
  end

  def headers(headers, {frontend_connection, backend_connection}) do
    case List.keyfind(headers, "authorization", 0) do
      {_key, "Bearer " <> token} ->
        case JwtToken.decode(token) do
          {:ok, {public_claims, private_claims}} ->
            session_id = Map.get(private_claims, "session_id")
            expires_at = Map.get(public_claims, "exp")

            if Application.get_env(:mu_identifier, :debug_session) do
              IO.inspect(session_id, label: "Session id from JWT")
            end

            frontend_connection =
              frontend_connection
              |> Plug.Conn.assign(:session_delivery_mode, :jwt_header)
              |> Plug.Conn.assign(:mu_session_id, session_id)
              |> Plug.Conn.assign(:mu_auth_allowed_groups, Map.get(private_claims, "allowed_groups"))
              |> Plug.Conn.assign(:session_allowed_groups_set_at, Map.get(private_claims, "allowed_groups_set_at"))
              |> Plug.Conn.assign(:session_lifetime_expires_at, expires_at)
              |> Plug.Conn.assign(:session_last_activity_at, Map.get(private_claims, "last_activity_at"))

            frontend_connection =
              # same state keys as for session cookie
              Plug.Conn.assign(frontend_connection, :previous_session_state, %{
                session_delivery_mode: frontend_connection.assigns[:session_delivery_mode],
                mu_session_id: frontend_connection.assigns[:mu_session_id],
                mu_auth_allowed_groups: frontend_connection.assigns[:mu_auth_allowed_groups],
                session_allowed_groups_set_at: frontend_connection.assigns[:session_allowed_groups_set_at],
                session_lifetime_expires_at: frontend_connection.assigns[:session_lifetime_expires_at],
                session_last_activity_at: frontend_connection.assigns[:session_last_activity_at]
              })

            {headers, {frontend_connection, backend_connection}}

          {:error, _} ->
            if Application.get_env(:mu_identifier, :debug_session) do
              IO.puts("Session authorization could not be decoded.")
            end
            frontend_connection = Plug.Conn.assign(frontend_connection, :jwt_token_unreadable, true)

            {headers, {frontend_connection, backend_connection}}
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
