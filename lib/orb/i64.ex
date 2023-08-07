defmodule Orb.I64 do
  @moduledoc """
  Type for 64-bit integer.
  """

  @behaviour Orb.CustomType

  @impl Orb.CustomType
  def wasm_type(), do: :i64

  # TODO: is the byte count of the pointer, or the items?
  # I think this should actually be removed from Orb.CustomType
  @impl Orb.CustomType
  def byte_count(), do: 8
end
