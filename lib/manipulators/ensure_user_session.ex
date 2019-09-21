defmodule Manipulators.EnsureUserSession do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    frontend_connection =
      if Plug.Conn.get_session(frontend_connection, :proxy_user_id) do
        IO.puts("keeping user_id")
        frontend_connection
      else
        IO.puts("creating new rand user_id")

        Plug.Conn.put_session(
          frontend_connection,
          :proxy_user_id,
          "http://mu.semte.ch/sessions/" <> UUID.uuid1()
        )
      end

    {headers, {frontend_connection,backend_connection}}
  end

  @impl true
  def chunk(_,_), do: :skip

  @impl true
  def finish(_,_), do: :skip
end
