defmodule Manipulators.EnsureUserSession do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    # Capture previous session state from the cookie BEFORE potentially
    # creating a new session, so WriteSessionCookie can detect new sessions.
    previous_session_state = %{
      session_delivery_mode: frontend_connection.assigns[:session_delivery_mode],
      mu_session_id: frontend_connection.assigns[:mu_session_id],
      mu_auth_allowed_groups: frontend_connection.assigns[:mu_auth_allowed_groups],
      groups_issued_at: frontend_connection.assigns[:groups_issued_at],
      session_valid_until: frontend_connection.assigns[:session_valid_until],
      session_last_activity_at: frontend_connection.assigns[:session_last_activity_at]
    }

    frontend_connection =
      if frontend_connection.assigns[:mu_session_id] do
        if( Application.get_env(:mu_identifier, :log_session) ) do
          IO.inspect( frontend_connection.assigns[:mu_session_id],
            label: "Keeping user id" )
        end
        frontend_connection
      else
        new_user_id = new_session_uri()

        if( Application.get_env(:mu_identifier, :log_session) ) do
          IO.inspect( new_user_id, label: "Created new user id" )
        end

        Plug.Conn.assign(frontend_connection, :mu_session_id, new_user_id)
      end

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
