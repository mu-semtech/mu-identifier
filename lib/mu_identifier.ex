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
      {Secret, %{}},
      {SessionRevocation, %{}},
      {Plug.Cowboy,
       scheme: :http,
       plug: Proxy,
       options: [
         port: port,
         compress: true,
         protocol_options: [
           idle_timeout: Application.get_env(:mu_identifier, :idle_timeout),
           max_request_line_length: Application.get_env(:mu_identifier, :max_url_length)
         ]
       ]}
    ]

    Logger.info("Mu Identifier starting on port #{port}")

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
