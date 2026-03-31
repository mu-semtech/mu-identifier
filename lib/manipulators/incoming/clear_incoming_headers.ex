defmodule Manipulators.Incoming.ClearIncomingHeaders do
  @moduledoc """
  Strips all mu-internal and consumed headers from the request before it reaches
  the backend.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    headers =
      headers
      # Consumed by request manipulators - strip so they don't reach the backend
      |> List.keydelete("authorization", 0)
      |> List.keydelete("mu-session-clear", 0)
      # Session identity headers (set by mu-identifier, not clients)
      |> List.keydelete("mu-session-id", 0)
      |> List.keydelete("revoked-mu-session-id", 0)
      |> List.keydelete("previous-mu-session-id", 0)
      # Call tracing headers
      |> List.keydelete("mu-call-id", 0)
      |> List.keydelete("mu-call-id-trail", 0)
      # Authorization headers
      |> List.keydelete("mu-auth-allowed-groups", 0)
      |> List.keydelete("revoked-mu-auth-allowed-groups", 0)
      |> List.keydelete("previous-mu-auth-allowed-groups", 0)
      |> List.keydelete("mu-auth-used-groups", 0)
      |> List.keydelete("mu-auth-scope", 0)
      |> List.keydelete("mu-auth-sudo", 0)
      |> List.keydelete("mu-unauthorized", 0)
      # Session control headers
      |> List.keydelete("mu-auth-reinstate-session", 0)
      |> List.keydelete("mu-session-delivery-mode", 0)
      |> List.keydelete("mu-session-valid-until", 0)
      |> List.keydelete("cookie", 0)
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
