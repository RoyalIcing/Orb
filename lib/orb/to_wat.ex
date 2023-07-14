defprotocol Orb.ToWat do
  @doc "Protocol for converting to WebAssembly text format (Wat)"
  def to_wat(data, indent)
end

# A lot of the instruction are implemented as tuples.
# They might all become structs in the future, which means this could be removed.
defimpl Orb.ToWat, for: Tuple do
  def to_wat(tuple, indent) do
    Orb.ToWat.Instructions.do_wat(tuple, indent)
  end
end
