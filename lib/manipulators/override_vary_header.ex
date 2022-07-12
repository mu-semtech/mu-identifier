defmodule Manipulators.OverrideVaryHeader do
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, connection) do
    # Adds the CORS header to the list of headers
    has_vary_header =
      headers
      |> List.keyfind("vary", 0)

    override_vary_header = Application.get_env(:mu_identifier, :override_vary_header)

    without_vary_header =
      headers
      |> List.keydelete("vary", 0)
      |> IO.inspect(label: "headers without vary")

    headers =
      if override_vary_header do
        [{"vary", override_vary_header} | without_vary_header]
        |> IO.inspect(label: "headers with new vary")
      else
        if has_vary_header do
          [{"vary", "accept, cookie"} | without_vary_header]
        else
          headers
        end
      end

    {headers, connection}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
