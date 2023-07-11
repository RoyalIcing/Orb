defmodule Orb.I32.Multiply do
  def neutralize(_, 0), do: 0
  def neutralize(0, _), do: 0
  def neutralize(a, 1), do: a
  def neutralize(1, b), do: b
  def neutralize(a, b), do: {:i32, :mul, {a, b}}
end
