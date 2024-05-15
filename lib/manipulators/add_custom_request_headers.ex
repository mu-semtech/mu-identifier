defmodule Manipulators.AddCustomRequestHeaders do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    # Clean all information which we are owner of within the stack
    clean_headers =
      headers
      |> List.keydelete("mu-session-id", 0)
      |> List.keydelete("mu-call-id", 0)
      |> List.keydelete("mu-call-id-trail", 0)
      |> List.keydelete("mu-auth-allowed-groups", 0)

    new_headers = [
      {"mu-session-id", Plug.Conn.get_session(frontend_connection, :proxy_user_id)},
      {"mu-call-id", Integer.to_string(Enum.random(0..1_000_000_000_000))}
      | clean_headers
    ]

    authorization_groups = Plug.Conn.get_session(frontend_connection, :mu_auth_allowed_groups)

    default_allowed_groups =
      Application.get_env(:mu_identifier, :default_mu_auth_allowed_groups_header)

    if Application.get_env(:mu_identifier, :log_incoming_allowed_groups) ||
         Application.get_env(:mu_identifier, :log_allowed_groups) do
      if authorization_groups do
        IO.inspect(authorization_groups, label: "Incoming allowed groups from cookie")
      else
        IO.inspect(default_allowed_groups, label: "Incoming allowed groups are default")
      end
    end

    headers_with_authorization =
      cond do
        authorization_groups == "CLEAR" ->
          new_headers

        authorization_groups ->
          [{"mu-auth-allowed-groups", authorization_groups} | new_headers]

        default_allowed_groups ->
          [{"mu-auth-allowed-groups", default_allowed_groups} | new_headers]

        true ->
          new_headers
      end

    {headers_with_authorization, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
