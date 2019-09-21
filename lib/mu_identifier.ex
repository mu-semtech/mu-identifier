defmodule MuIdentifier do
  @moduledoc """
  MuIdentifier identifies user agents and forwards messages
  """

  use Application
  require Logger

  def start(_argv, _args) do
    port = 80
    IO.puts("Running Proxy with Cowboy on port #{port}")

    children = [
      {Plug.Cowboy, scheme: :http, plug: Proxy, options: [port: port]}
    ]

    Logger.info("Mu Identifier starting on port #{port}")

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
