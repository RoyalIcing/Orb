defmodule Orb.MixProject do
  use Mix.Project

  def project do
    [
      app: :orb,
      version: "0.0.1",
      elixir: "~> 1.14.2",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "DSL for WebAssembly",
      package: package(),
      source_url: "https://github.com/RoyalIcing/orb"
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
  	[
  	  name: :orb,
      maintainers: ["Patrick George Wyndham Smith"],
  	  licenses: ["Apache 2.0"],
  	  links: %{"GitHub" => "https://github.com/RoyalIcing/orb"}
  	]
  end
end
