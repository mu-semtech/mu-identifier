defmodule Manipulators.EnsureUserSession do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    frontend_connection = Plug.Conn.fetch_session(frontend_connection)

    frontend_connection =
      if Plug.Conn.get_session(frontend_connection, :proxy_user_id) do
        if( Application.get_env(:mu_identifier, :log_session) ) do
          IO.inspect( Plug.Conn.get_session(frontend_connection, :proxy_user_id),
            label: "Keeping user id" )
        end
        frontend_connection
      else
        new_user_id = new_session_uri()

        if( Application.get_env(:mu_identifier, :log_session) ) do
          IO.inspect( new_user_id, label: "Created new user id" )
        end

        Plug.Conn.put_session(
          frontend_connection,
          :proxy_user_id,
          new_user_id
        )
      end

    previous_session_state = %{
      user_id: Plug.Conn.get_session(frontend_connection, :proxy_user_id),
      allowed_groups: Plug.Conn.get_session(frontend_connection, :mu_auth_allowed_groups),
      valid_until: frontend_connection.assigns[:session_valid_until]
    }

    frontend_connection = Plug.Conn.assign(frontend_connection, :mu_previous_session_state, previous_session_state)

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
