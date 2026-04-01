defmodule Manipulators.Incoming.ClearIncomingHeaders do
  @moduledoc """
  Cleans received headers, new state is written in Manipulators.Incoming.AddCustomRequestHeaders.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    headers =
      headers
      # passed through the stack from identifier
      |> List.keydelete("mu-session-id", 0)
      |> List.keydelete("mu-auth-allowed-groups", 0)
      |> List.keydelete("mu-call-id", 0)
      # consumed by earlier manipulators
      |> List.keydelete("authorization", 0)
      |> List.keydelete("mu-session-clear", 0)
      # communication to backend
      |> List.keydelete("mu-unauthorized", 0)
      |> List.keydelete("revoked-mu-session-id", 0)
      |> List.keydelete("cleared-mu-session-id", 0)
      |> List.keydelete("cleared-mu-auth-allowed-groups", 0)
      |> List.keydelete("previous-mu-auth-allowed-groups", 0)
      # mu-authorization headers
      |> List.keydelete("mu-auth-used-groups", 0)
      |> List.keydelete("mu-auth-scope", 0)
      |> List.keydelete("mu-auth-sudo", 0)
      # unexpected headers
      |> List.keydelete("cookie", 0)
      |> List.keydelete("mu-auth-token", 0)
      |> List.keydelete("mu-call-id-trail", 0)
      |> List.keydelete("mu-auth-reinstate-session", 0)
      |> List.keydelete("mu-session-delivery-mode", 0)
      |> List.keydelete("mu-session-valid-until", 0)
      |> List.keydelete("cache-keys", 0)
      |> List.keydelete("clear-keys", 0)

    {headers, connection}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
