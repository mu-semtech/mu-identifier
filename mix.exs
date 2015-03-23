defmodule Proxy.Mixfile do
  use Mix.Project

  def project do
    [app: :proxy,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps,
     aliases: aliases]
  end

  # Some command line aliases
  def aliases do
    [serve: ["run", &Proxy.start/1]]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :cowboy, :plug, :hackney]]
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
    [{:cowboy, "~> 1.0"},
     {:plug, "~> 0.8"},
     {:hackney, "~> 0.14"},
     {:uuid, "~> 1.0.0"}]
  end
end
