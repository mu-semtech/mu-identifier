defmodule Manipulators.EnforceInvalidCredential do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    {headers, frontend_connection} =
      SessionExpiration.handle(
        frontend_connection.assigns[:invalid_credential_strategy],
        frontend_connection,
        headers
      )

    {headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
