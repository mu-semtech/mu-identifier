defmodule Manipulators.WriteJwtToken do
  @moduledoc """
  Issues a `Mu-Auth-Token` JWT response header when the delivery mode is `:jwt_header`
  and the session state has changed since the request began.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection})
      when frontend_connection.assigns.mu_auth_unauthorized == true and
             frontend_connection.assigns.reinstate_revoked_session != true do
    {headers, {frontend_connection, backend_connection}}
  end

  def headers(headers, {frontend_connection, backend_connection}) do
    headers =
      if frontend_connection.assigns[:session_delivery_mode] == :jwt_header do
        previous = frontend_connection.assigns[:mu_previous_session_state]
        current = %{
          session_delivery_mode: frontend_connection.assigns[:session_delivery_mode],
          mu_session_id: frontend_connection.assigns[:mu_session_id],
          mu_auth_allowed_groups: frontend_connection.assigns[:mu_auth_allowed_groups],
          groups_issued_at: frontend_connection.assigns[:groups_issued_at],
          session_valid_until: frontend_connection.assigns[:session_valid_until],
          session_last_activity_at: frontend_connection.assigns[:session_last_activity_at]
        }

        if current != previous do
          private =
            %{
              "session_id" => current.mu_session_id,
              "allowed_groups" => current.mu_auth_allowed_groups,
              "allowed_groups_set_at" => current.groups_issued_at,
              "last_activity_at" => current.session_last_activity_at
            }
            |> Map.filter(fn {_k, v} -> v != nil end)

          [{"mu-auth-token", JwtToken.encode(current.session_valid_until, private)} | headers]
        else
          headers
        end
      else
        headers
      end

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip


end
