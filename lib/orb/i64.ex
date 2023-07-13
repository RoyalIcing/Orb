defmodule Orb.I64 do
  @behaviour Orb.Type

  @impl Orb.Type
  def wasm_type(), do: :i64

  # TODO: is the byte count of the pointer, or the items?
  # I think this should actually be removed from Orb.Type
  @impl Orb.Type
  def byte_count(), do: 8
end
