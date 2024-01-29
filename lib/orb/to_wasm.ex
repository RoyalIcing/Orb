defprotocol Orb.ToWasm do
  @doc "Protocol for converting to WebAssembly binary format (.wasm)"
  def to_wasm(data, options)
end
