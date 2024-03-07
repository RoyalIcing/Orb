defmodule Orb.Numeric.Add do
  @moduledoc """
  WebAssembly numeric `add` instruction:
  - `i32.add`
  - `i64.add`
  - `f32.add`
  - `f64.add`

  [MDN reference](https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Numeric/Addition)
  """
  alias Orb.CustomType

  require alias Orb.Ops

  # Perform at comptime.
  def optimized(_type, a, b) when is_integer(a) and is_integer(b), do: a + b
  # Add zero to anything is that same thing.
  def optimized(_type, a, 0), do: a
  def optimized(_type, 0, b), do: b

  def optimized(type, a, b) when Ops.is_primitive_type(type),
    do: Orb.Instruction.new(type, :add, [a, b])

  def optimized(type, a, b), do: Orb.Instruction.new(CustomType.resolve!(type), :add, [a, b])
end
