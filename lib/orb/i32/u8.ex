defmodule Orb.I32.U8 do
  @moduledoc """
  Type for unsigned 32-bit integer interpreted as an 8-bit byte.
  """

  @behaviour Orb.CustomType

  @impl Orb.CustomType
  def wasm_type(), do: :i32

  # TODO: remove this
  @impl Orb.CustomType
  def load_instruction(), do: :load8_u
end
