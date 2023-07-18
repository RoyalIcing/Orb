defmodule Orb.I32.U8 do
  @moduledoc """
  Type for unsigned 32-bit integer interpreted as an 8-bit byte.
  """

  @behaviour Orb.Type

  @impl Orb.Type
  def wasm_type(), do: :i32

  @impl Orb.Type
  def load_instruction(), do: :load8_u

  @impl Orb.Type
  def byte_count(), do: 1
end
