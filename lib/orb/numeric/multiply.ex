defmodule Orb.Numeric.Multiply do
  @moduledoc """
  WebAssembly numeric `mul` instruction:
  - `i32.mul`
  - `i64.mul`
  - `f32.mul`
  - `f64.mul`

  [MDN reference](https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Numeric/Multiplication)
  """
  alias Orb.CustomType

  alias require Orb.Ops

  # Perform at comptime.
  def optimized(_type, a, b) when is_integer(a) and is_integer(b), do: a * b
  # Multiply anything by zero equals zero.
  def optimized(type, _, 0), do: Orb.Instruction.wrap_constant!(type, 0)
  def optimized(type, 0, _), do: Orb.Instruction.wrap_constant!(type, 0)
  # Multiply one by anything is that same thing.
  def optimized(_type, a, 1), do: a
  def optimized(_type, 1, b), do: b

  # Finally, spit out the runtime instruction.
  def optimized(type, a, b) when Ops.is_primitive_type(type),
    do: Orb.Instruction.new(type, :mul, [a, b])

  def optimized(type, a, b), do: Orb.Instruction.new(CustomType.resolve!(type), :mul, [a, b])
end
