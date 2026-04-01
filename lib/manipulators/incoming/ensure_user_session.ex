defmodule Manipulators.Incoming.EnsureUserSession do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    frontend_connection =
      if frontend_connection.assigns[:mu_session_id] do
        if( Application.get_env(:mu_identifier, :log_session) ) do
          IO.inspect( frontend_connection.assigns[:mu_session_id], label: "Keeping user id" )
        end
        frontend_connection
      else
        new_mu_session_id = new_session_uri()

        if( Application.get_env(:mu_identifier, :log_session) ) do
          IO.inspect( new_mu_session_id, label: "Created new session id" )
        end

        Plug.Conn.assign(frontend_connection, :mu_session_id, new_mu_session_id)
      end

    {headers, {frontend_connection, backend_connection}}
  end

  def new_session_uri do
    "http://mu.semte.ch/sessions/" <> UUID.uuid1()
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
