defmodule Manipulators.Incoming.HandleInvalidCredentials do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    cond do
      frontend_connection.assigns[:session_cookie_unreadable] ->
        {headers, frontend_connection} =
          SessionInvalidation.register(
            Application.get_env(:mu_identifier, :invalid_session_strategy),
            frontend_connection,
            headers,
            :invalid_session_cookie
          )

        {headers, {frontend_connection, backend_connection}}

      frontend_connection.assigns[:jwt_token_unreadable] ->
        {headers, frontend_connection} =
          SessionInvalidation.register(
            Application.get_env(:mu_identifier, :invalid_jwt_token_strategy),
            frontend_connection,
            headers,
            :invalid_jwt_token
          )

        {headers, {frontend_connection, backend_connection}}

      true ->
        {headers, {frontend_connection, backend_connection}}
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
