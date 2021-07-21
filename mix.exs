defmodule Proxy.Mixfile do
  use Mix.Project

  def project do
    [app: :mu_identifier,
     version: "1.9.1",
     elixir: "~> 1.7",
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      extra_applications: [:logger, :plug_mint_proxy, :cowboy, :plug],
      mod: {MuIdentifier, []},
      env: []
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:plug_mint_proxy, git: "https://github.com/madnificent/plug-mint-proxy.git", tag: "v0.2.0"},
      {:cowboy_ws_proxy, git: "https://github.com/ajuvercr/elixir-cowboy-ws-proxy-handler.git", tag: "v0.1"},
     {:uuid, "~> 1.1"},
      {:gun, "~> 2.0.0-rc.2"},
     {:replug, "~> 0.1.0"},
     {:secure_random, "~> 0.5"},
    {:exsync, "~> 0.2", only: :dev},
     {:observer_cli, "~> 1.5"}]
  end
end
