defprotocol Orb.ToWat do
  @doc "Convert to WebAssembly text format (Wat)"
  def to_wat(data, indent)
end

defimpl Orb.ToWat, for: Tuple do
  def to_wat({:i32_const, value}, _indent) do
    ["(i32.const ", to_string(value), ")"]
  end
end
