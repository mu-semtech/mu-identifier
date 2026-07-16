defmodule Manipulators.Outgoing.CustomSessionWriter do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    case List.keyfind(frontend_connection.req_headers, "x-custom-session-id", 0) do
      nil ->
        {headers, {frontend_connection, backend_connection}}

      {_key, _value} ->
        session_id = frontend_connection.assigns[:mu_session_id]
        allowed_groups = frontend_connection.assigns[:mu_auth_allowed_groups]

        headers =
          if session_id,
            do: [{"x-custom-session-id-echo", session_id} | headers],
            else: headers

        headers =
          if allowed_groups,
            do: [{"x-custom-allowed-groups-echo", allowed_groups} | headers],
            else: headers

        {headers, {frontend_connection, backend_connection}}
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
