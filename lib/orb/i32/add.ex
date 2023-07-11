defmodule Orb.I32.Add do
  def neutralize(a, 0), do: a
  def neutralize(0, b), do: b
  def neutralize(a, b), do: {:i32, :add, {a, b}}
end
