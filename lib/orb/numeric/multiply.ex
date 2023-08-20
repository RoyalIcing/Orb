defmodule Orb.Numeric.Multiply do
  @moduledoc """
  WebAssembly numeric `mul` instruction:
  - `i32.mul`
  - `i64.mul`
  - `f32.mul`
  - `f64.mul`

  [MDN reference](https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Numeric/Multiplication)
  """

  # Perform at comptime.
  def optimized(_type, a, b) when is_integer(a) and is_integer(b), do: a * b
  # Multiply anything by zero equals zero.
  def optimized(_type, _, 0), do: 0
  def optimized(_type, 0, _), do: 0
  # Multiply anything by one is that same thing.
  def optimized(_type, a, 1), do: a
  def optimized(_type, 1, b), do: b
  # Finally, spit out the instruction.
  def optimized(type, a, b), do: Orb.Instruction.new(type.wasm_type(), :mul, [a, b])
end
