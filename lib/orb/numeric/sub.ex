defmodule Orb.Numeric.Subtract do
  def optimized(_type, a, 0), do: a
  def optimized(type, a, b), do: {type.wasm_type(), :sub, {a, b}}
end
