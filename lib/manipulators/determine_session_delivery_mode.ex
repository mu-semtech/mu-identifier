defmodule Manipulators.DetermineSessionDeliveryMode do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    mode =
      case List.keyfind(headers, "mu-session-delivery-mode", 0) do
        nil ->
          Map.get(frontend_connection.assigns, :session_delivery_mode, :cookie)

        {_key, value} ->
          case value do
            "https://services.semantic.works/mu-identifier/session-delivery/jwt-header" -> :jwt_header
            ":jwt-header" -> :jwt_header
            "https://services.semantic.works/mu-identifier/session-delivery/cookie" -> :cookie
            ":cookie" -> :cookie
            _ -> raise "Unknown Mu-Session-Delivery-Mode value: #{value}. Known values: https://services.semantic.works/mu-identifier/session-delivery/jwt-header, :jwt-header, https://services.semantic.works/mu-identifier/session-delivery/cookie, :cookie"
          end
      end

    frontend_connection = Plug.Conn.assign(frontend_connection, :session_delivery_mode, mode)

    frontend_connection =
      if mode == :jwt_header do
        previous = frontend_connection.assigns[:mu_previous_session_state]
        current = %{
          user_id: Plug.Conn.get_session(frontend_connection, :proxy_user_id),
          allowed_groups: Plug.Conn.get_session(frontend_connection, :mu_auth_allowed_groups),
          valid_until: frontend_connection.assigns[:session_valid_until]
        }
        if previous != current do
          Plug.Conn.assign(frontend_connection, :emit_jwt, true)
        else
          frontend_connection
        end
      else
        frontend_connection
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
