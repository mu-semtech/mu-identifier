defmodule Manipulators.ClientEnforcedSessionClearing do
  @moduledoc """
  Clears the session assigns when the client sends a `Mu-Session-Clear` header.

  Only active when `MU_ALLOW_SESSION_CLEAR_HEADER` is enabled.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    # TODO: it would be clearer if the if and the case would be the same nesting
    # NOTE: mu-session-clear is always stripped, even when the feature is disabled, so it
    # is never forwarded to the backend.
    case List.keytake(headers, "mu-session-clear", 0) do
      {{_key, _value}, remaining_headers} ->
        if Application.get_env(:mu_identifier, :allow_session_clear_header) do
          previous_session_id = frontend_connection.assigns[:mu_session_id] || ""
          previous_allowed_groups = frontend_connection.assigns[:mu_auth_allowed_groups] || ""

          frontend_connection =
            frontend_connection
            |> Plug.Conn.assign(:mu_session_id, nil)
            |> Plug.Conn.assign(:mu_auth_allowed_groups, nil)
            |> Plug.Conn.assign(:groups_issued_at, nil)
            |> Plug.Conn.assign(:session_valid_until, nil)
            |> Plug.Conn.assign(:session_last_activity_at, nil)

          audit_headers = [
            {"previous-mu-session-id", previous_session_id},
            {"previous-mu-auth-allowed-groups", previous_allowed_groups}
          ]

          {audit_headers ++ remaining_headers, {frontend_connection, backend_connection}}
        else
          {remaining_headers, {frontend_connection, backend_connection}}
        end

      nil ->
        {headers, {frontend_connection, backend_connection}}
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
