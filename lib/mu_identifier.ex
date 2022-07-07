defmodule MuIdentifier do
  @moduledoc """
  MuIdentifier identifies user agents and forwards messages
  """

  use Application
  require Logger

  def start(_argv, _args) do
    port = 80
    IO.puts("Running Proxy with Cowboy on port #{port}")

    # TODO, this could be cleaner with `:cowboy.start_clear`
    children = [
      {Secret, %{}},
      {Plug.Cowboy,
       scheme: :http, plug: Proxy, options: [dispatch: dispatch, port: port, compress: true]}
    ]

    Logger.info("Mu Identifier starting on port #{port}")

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp dispatch do
    default = %{
      host: "dispatcher",
      port: 80,
      path: "/"
    }

    f = fn req -> default |> Map.put(:path, req.path <> "?" <> req.qs) end

    [
      {:_,
       [
         {"/.mu/ws/[...]", WsHandler, {f, default}},
         {:_, Plug.Cowboy.Handler, {Proxy, []}}
       ]}
    ]
  end
end
