defmodule Manipulators.AddCustomRequestHeaders do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    unauthorized = frontend_connection.assigns[:mu_unauthorized]

    session_id_header =
      if unauthorized do
        {"revoked-mu-session-id", frontend_connection.assigns[:mu_session_id]}
      else
        {"mu-session-id", frontend_connection.assigns[:mu_session_id]}
      end

    new_headers = [
      session_id_header,
      {"mu-call-id", Integer.to_string(Enum.random(0..1_000_000_000_000))}
      | headers
    ]

    authorization_groups = frontend_connection.assigns[:mu_auth_allowed_groups]

    default_allowed_groups =
      Application.get_env(:mu_identifier, :default_mu_auth_allowed_groups_header)

    if Application.get_env(:mu_identifier, :log_incoming_allowed_groups) ||
         Application.get_env(:mu_identifier, :log_allowed_groups) do
      if authorization_groups do
        IO.inspect(authorization_groups, label: "Incoming allowed groups")
      else
        IO.inspect(default_allowed_groups, label: "Incoming allowed groups are default")
      end
    end

    headers_with_authorization =
      cond do
        unauthorized && authorization_groups ->
          [{"revoked-mu-auth-allowed-groups", authorization_groups} | new_headers]

        unauthorized ->
          new_headers

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
