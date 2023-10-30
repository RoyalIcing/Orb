defmodule Orb.Numeric.Subtract do
  @moduledoc """
  WebAssembly numeric `sub` instruction:
  - `i32.sub`
  - `i64.sub`
  - `f32.sub`
  - `f64.sub`

  [MDN reference](https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Numeric/Subtraction)
  """

  # Perform at comptime.
  def optimized(_type, a, b) when is_integer(a) and is_integer(b), do: a - b
  # Minus zero from anything is that same thing.
  def optimized(_type, a, 0), do: a
  def optimized(type, a, b), do: Orb.Instruction.new(type.wasm_type(), :sub, [a, b])
end
