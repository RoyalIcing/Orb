defprotocol Orb.ToWat do
  @doc "Convert to WebAssembly text format (Wat)"
  def to_wat(data, indent)
end

defimpl Orb.ToWat, for: Tuple do
  def to_wat(tuple, indent) do
    Orb.ToWat.Instructions.do_wat(tuple, indent)
  end
end
