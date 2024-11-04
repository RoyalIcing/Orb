defmodule Orb.I32.U16 do
  @moduledoc """
  Type for unsigned 32-bit integer interpreted as unsigned 16-bit (double byte).
  """

  with @behaviour Orb.CustomType do
    @impl Orb.CustomType
    def wasm_type(), do: :i32

    @impl Orb.CustomType
    def load_instruction(), do: :load16_u
  end
end
