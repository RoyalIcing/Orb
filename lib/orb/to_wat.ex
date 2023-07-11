defprotocol Orb.ToWat do
  @doc "Convert to WebAssembly text format (Wat)"
  def to_wat(data, indent)
end
