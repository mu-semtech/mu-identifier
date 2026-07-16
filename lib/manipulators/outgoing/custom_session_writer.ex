defmodule Manipulators.Outgoing.CustomSessionWriter do
  @behaviour ProxyManipulator

  @impl true
  def headers(_, _), do: :skip

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
