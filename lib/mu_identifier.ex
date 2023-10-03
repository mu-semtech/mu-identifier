defmodule MuIdentifier do
  @moduledoc """
  MuIdentifier identifies user agents and forwards messages
  """

  use Application
  require Logger

  def start(_argv, _args) do
    port = 80
    IO.puts("Running Proxy with Bandit on port #{port}")

    children = [
      {Secret, %{}},
      {Bandit,
       scheme: :http,
       plug: Proxy,
       port: port}
    ]

    Logger.info("Mu Identifier starting on port #{port}")

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
