defmodule Orb.Numeric.NotEqual do
  @moduledoc """
  WebAssembly numeric `ne` instruction:
  - `i32.ne`
  - `i64.ne`
  - `f32.ne`
  - `f64.ne`

  [MDN reference](https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Numeric/Not_equal)
  """
  alias Orb.CustomType

  def optimized(type, a, b), do: Orb.Instruction.new(CustomType.resolve!(type), :ne, [a, b])
end
