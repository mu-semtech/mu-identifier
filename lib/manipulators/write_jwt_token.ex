defmodule Manipulators.WriteJwtToken do
  @moduledoc """
  Issues a JWT when the delivery mode is `:jwt_header` or `:jwt_body`
  and the session state has changed since the request began.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    skip_session_write =
      frontend_connection.assigns[:mu_unauthorized] == true &&
        frontend_connection.assigns[:reinstate_revoked_session] != true

    mode = frontend_connection.assigns[:session_delivery_mode]

    {headers, frontend_connection} =
      if mode in [:jwt_header, :jwt_body] && !skip_session_write do
        previous = frontend_connection.assigns[:previous_session_state]
        current = %{
          session_delivery_mode: mode,
          mu_session_id: frontend_connection.assigns[:mu_session_id],
          mu_auth_allowed_groups: frontend_connection.assigns[:mu_auth_allowed_groups],
          session_allowed_groups_set_at: frontend_connection.assigns[:session_allowed_groups_set_at],
          session_max_expires_at: frontend_connection.assigns[:session_max_expires_at],
          session_last_activity_at: frontend_connection.assigns[:session_last_activity_at]
        }

        if current != previous do
          private =
            %{
              "session_id" => current.mu_session_id,
              "allowed_groups" => current.mu_auth_allowed_groups,
              "allowed_groups_set_at" => current.session_allowed_groups_set_at,
              "last_activity_at" => current.session_last_activity_at
            }
            |> Map.filter(fn {_k, v} -> v != nil end)

          jwt = JwtToken.encode(current.session_max_expires_at, private)

          if mode == :jwt_header do
            {[{"mu-auth-token", jwt} | headers], frontend_connection}
          else
            headers =
              headers
              |> List.keydelete("content-type", 0)
              |> List.keydelete("content-length", 0)
              |> List.keydelete("transfer-encoding", 0)
              |> then(&[{"content-type", "application/jwt"} | &1])

            frontend_connection =
              frontend_connection
              |> Plug.Conn.assign(:jwt_body_token, jwt)
              |> Plug.Conn.register_before_send(fn conn ->
                case conn.state do
                  :chunked -> %{conn | status: 200}
                  _ -> %{conn | status: 200, resp_body: jwt}
                end
              end)

            {headers, frontend_connection}
          end
        else
          {headers, frontend_connection}
        end
      else
        {headers, frontend_connection}
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_chunk, {frontend_connection, backend_connection}) do
    case frontend_connection.assigns[:jwt_body_token] do
      nil ->
        :skip

      jwt ->
        if frontend_connection.assigns[:jwt_body_sent] do
          {"", {frontend_connection, backend_connection}}
        else
          frontend_connection = Plug.Conn.assign(frontend_connection, :jwt_body_sent, true)
          {jwt, {frontend_connection, backend_connection}}
        end
    end
  end

  @impl true
  def finish(_, _), do: :skip
end
