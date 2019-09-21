defmodule Manipulators.PutCacheClearHeaders do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    # When the cache is not set, or when it is "no-cache", we inform
    # browsers in all headers available to us to not add any caches.

    # Some browsers (IE) handle caching differently than their peers.
    # The mu-identifier makes this easier to support by providing the
    # necessary headers.

    cache_clear_header =
      headers
      |> List.keyfind("cache-control", 0, {nil, :no_cache_control_header})
      |> elem(1)

    headers =
      case cache_clear_header do
        "no-cache" ->
          headers
          |> put_new_key("pragma", "no-cache")
          |> put_new_key("expires", "-1")

        :no_cache_control_header ->
          headers
          |> put_new_key("pragma", "no-cache")
          |> put_new_key("expires", "-1")
          |> put_new_key("cache-control", "no-cache")

        _ ->
          headers
      end

    {headers, connection}
  end

  @impl true
  def chunk(_,_), do: :skip

  @impl true
  def finish(_,_), do: :skip

  defp put_new_key(list, key, value) do
    # Adds the key/value tuple to the list, unless it is already there

    if List.keymember?(list, key, 0) do
      list
    else
      [{key, value} | list]
    end
  end
end
