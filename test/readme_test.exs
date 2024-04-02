defmodule ReadmeTest do
  use ExUnit.Case, async: true

  test "version in readme matches mix.exs" do
    readme_markdown = File.read!(Path.join(__DIR__, "../README.md"))
    version = Mix.Project.config()[:version]
    assert readme_markdown =~ ~s({:orb, "~> #{version}"})
  end

  test "version in site install matches mix.exs" do
    readme_markdown = File.read!(Path.join(__DIR__, "../site/install.md"))
    version = Mix.Project.config()[:version]
    assert readme_markdown =~ ~s({:orb, "~> #{version}"})
  end
end
