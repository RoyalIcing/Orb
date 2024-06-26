defmodule Orb.F32 do
  @moduledoc false

  require Orb.Ops, as: Ops
  alias Orb.Instruction

  with @behaviour Orb.CustomType do
    @impl Orb.CustomType
    def wasm_type, do: :f32
  end

  for op <- Ops.f32(1) do
    def unquote(op)(a) do
      Instruction.f32(unquote(op), a)
    end
  end

  for op <- Ops.f32(2) do
    def unquote(op)(a, b) do
      Instruction.f32(unquote(op), a, b)
    end
  end
end
