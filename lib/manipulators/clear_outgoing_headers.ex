defmodule Manipulators.ClearOutgoingHeaders do
  @moduledoc """
  Strips mu-internal headers from the backend response before it reaches the client.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    headers =
      headers
      # Authorization headers (read by response manipulators before this runs)
      |> List.keydelete("mu-auth-allowed-groups", 0)
      |> List.keydelete("mu-auth-used-groups", 0)
      |> List.keydelete("mu-auth-scope", 0)
      |> List.keydelete("mu-auth-sudo", 0)
      |> List.keydelete("mu-unauthorized", 0)
      # Session control headers (read by response manipulators before this runs)
      |> List.keydelete("mu-auth-reinstate-session", 0)
      |> List.keydelete("mu-session-delivery-mode", 0)
      |> List.keydelete("mu-session-valid-until", 0)
      |> List.keydelete("set-cookie", 0)
      |> List.keydelete("mu-auth-token", 0)
      # Cache headers
      |> List.keydelete("x-cache", 0)
      |> List.keydelete("cache-keys", 0)
      |> List.keydelete("clear-keys", 0)

    {headers, connection}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
