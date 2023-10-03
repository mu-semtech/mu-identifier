defmodule Manipulators.ChunkedResponse do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {frontend_connection, backend_connection}) do
    updated_headers =
      [ { "transfer-encoding", "chunked" }
        |
        headers
        |> List.keydelete("content-length", 0)
        |> List.keydelete("transfer-encoding", 0)
      ]

    {updated_headers, {frontend_connection, backend_connection}}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip

end
