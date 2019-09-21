defmodule Proxy.Mixfile do
  use Mix.Project

  def project do
    [app: :mu_identifier,
     version: "1.6.1",
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
    [# {:plug_proxy, path: "/home/madnificent/code/elixir/plug-proxy.git"},
     # {:plug_proxy, git: "https://github.com/madnificent/plug-proxy.git", branch: "feature/upgrade-to-4.0"},
      {:plug_mint_proxy, git: "https://github.com/madnificent/plug-mint-proxy.git", branch: "back-to-the-future"},
      {:uuid, "~> 1.1"}]
  end
end
