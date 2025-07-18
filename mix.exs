defmodule Orb.MixProject do
  use Mix.Project

  @source_url "https://github.com/RoyalIcing/Orb"

  def project do
    [
      app: :orb,
      version: "0.2.2",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "DSL for WebAssembly",
      package: package(),

      # Docs
      name: "Orb",
      docs: docs(),
      source_url: @source_url,
      homepage_url: "https://useorb.dev/"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:wasmex, "~> 0.11.2", only: :test},
      {:jason, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.31.2", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      name: :orb,
      maintainers: ["Patrick George Wyndham Smith"],
      licenses: ["BSD-3-Clause"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      # The main page in the docs
      main: "Orb",
      logo: "orb-logo-blue-orange.svg",
      extras: [
        # {"README.md", title: "Home"},
        # {"https://useorb.dev/", title: "Website"},
        {"examples/01-intro.livemd", title: "Example: Introduction"},
        {"examples/temperature-converter.livemd", title: "Example: Temperature Converter"},
        {"examples/mime-type.livemd", title: "Example: Mime Type"},
        {"examples/youtube-url-parser.livemd", title: "Example: YouTube URL Parser"}
      ]
    ]
  end
end
