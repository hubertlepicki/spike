defmodule Spike.MixProject do
  use Mix.Project

  def project do
    [
      app: :spike,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      source_url: "https://github.com/hubertlepicki/spike",
      homepage_url: "https://github.com/hubertlepicki/spike",
      docs: [
        main: "readme",
        logo: "assets/spike-logo.png",
        extras: ["README.md"]

      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Spike.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:vex, "~> 0.9"},
      {:tarams, "~> 1.6"},
      {:mappable, "~> 0.2"},
      {:map_diff, "~> 1.3"},
      {:uuid, "~> 1.1"},
      {:jason, "~> 1.3"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
    ]
  end
end
