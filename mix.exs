defmodule Spike.MixProject do
  use Mix.Project

  @description "Spike helps you build stateul forms / UIs with Phoenix LiveView (and/or Surface UI)"

  def project do
    [
      app: :spike,
      description: @description,
      version: "0.3.0-rc.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      source_url: "https://github.com/hubertlepicki/spike",
      homepage_url: "https://github.com/hubertlepicki/spike",
      docs: [
        main: "readme",
        logo: "assets/spike-logo.png",
        extras: ["README.md"]
      ],
      package: package()
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/hubertlepicki/spike"
      },
      files: ~w(lib mix.exs mix.lock README.md LICENSE)
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
      {:tarams, "~> 1.8"},
      {:mappable, "~> 0.2"},
      {:map_diff, "~> 1.3"},
      {:uuid, "~> 1.1"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end
end
