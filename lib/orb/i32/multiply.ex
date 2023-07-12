defmodule Orb.I32.Multiply do
  # Perform at comptime.
  def neutralize(a, b) when is_integer(a) and is_integer(b), do: a * b
  # Multiply anything by zero equals zero.
  def neutralize(_, 0), do: 0
  def neutralize(0, _), do: 0
  # Multiply anything by one is that same thing.
  def neutralize(a, 1), do: a
  def neutralize(1, b), do: b
  # Finally, spit out the instruction.
  def neutralize(a, b), do: {:i32, :mul, {a, b}}
end
