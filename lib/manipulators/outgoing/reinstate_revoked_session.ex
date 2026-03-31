defmodule Manipulators.Outgoing.ReinstateRevokedSession do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    if List.keyfind(headers, "mu-auth-reinstate-session", 0) do
      frontend_connection.assigns[:mu_session_id]
      |> RevocationStore.reinstate_mu_session_id()

      frontend_connection = Plug.Conn.assign(frontend_connection, :reinstate_revoked_session, true)

      {headers, {frontend_connection, backend_connection}}
    else
      {headers, {frontend_connection, backend_connection}}
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
