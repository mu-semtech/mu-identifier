defmodule Proxy.Mixfile do
  use Mix.Project

  def project do
    [app: :proxy,
     version: "1.6.1",
     elixir: "~> 1.0",
     deps: deps(),
     aliases: aliases()]
  end

  # Some command line aliases
  def aliases do
    [server: "run --no-halt"]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      extra_applications: [:logger, :cowboy, :plug, :hackney],
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
    [{:plug_proxy, git: "https://github.com/madnificent/plug-proxy.git"},
     {:plug_cowboy, "~> 1.0"},
     {:uuid, "~> 1.1"},
     {:secure_random, "~> 0.5"}]
  end
end
