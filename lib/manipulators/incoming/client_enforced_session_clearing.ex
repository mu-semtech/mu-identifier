defmodule Manipulators.Incoming.ClientEnforcedSessionClearing do
  @moduledoc """
  Clear session when the client sends a `Mu-Session-Clear` header and `MU_ALLOW_SESSION_CLEAR_HEADER` is set.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    allow_session_clearing = Application.get_env(:mu_identifier, :allow_session_clear_header)
    requested_session_clearing = List.keymember?(headers, "mu-session-clear", 0)

    if allow_session_clearing && requested_session_clearing do
      frontend_connection =
        frontend_connection
        |> Plug.Conn.assign(:user_cleared_mu_session_id, frontend_connection.assigns[:mu_session_id])
        |> Plug.Conn.assign(:user_cleared_mu_auth_allowed_groups, frontend_connection.assigns[:mu_auth_allowed_groups])
        |> SessionInvalidation.reset_session()

      { headers, {frontend_connection, backend_connection} }
    else
      { headers, {frontend_connection, backend_connection} }
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
