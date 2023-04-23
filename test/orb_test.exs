defmodule OrbTest do
  use ExUnit.Case
  doctest Orb

  test "greets the world wide web" do
    assert Orb.hello() == :web
  end
end
