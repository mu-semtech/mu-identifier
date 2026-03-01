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

            # TODO: Use Conn.assign instead of put_session and create a separate
            # manipulator to either write the session or issue a JWT at the end.
            # Code depending on Plug.Conn.get_session would need updating too.
            # Currently JWT issuance reads from session state then clears it.
            frontend_connection =
              frontend_connection
              |> Plug.Conn.put_session(:proxy_user_id, session_id)
              |> Plug.Conn.put_session(:mu_auth_allowed_groups, Map.get(private_claims, "allowed_groups"))
              |> Plug.Conn.assign(:session_valid_until, expires_at)
              |> Plug.Conn.assign(:session_delivery_mode, :jwt_header)

            {remaining_headers, {frontend_connection, backend_connection}}

          {:error, _} ->
            # TODO: return a 401 response to indicate an invalid token was supplied.
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
