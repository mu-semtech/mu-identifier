defmodule Manipulators.ClearMuInternalKeys do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    headers =
      headers
      |> List.keydelete("x-cache", 0)
      |> List.keydelete("mu-auth-allowed-groups", 0)
      |> List.keydelete("mu-auth-used-groups", 0)
      |> List.keydelete("mu-auth-scope", 0)
      |> List.keydelete("cache-keys", 0)
      |> List.keydelete("clear-keys", 0)
      |> List.keydelete("mu-auth-sudo", 0)

    { headers, connection }
  end

  @impl true
  def chunk(_,_), do: :skip

  @impl true
  def finish(_,_), do: :skip
end
