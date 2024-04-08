defmodule Orb.F64 do
  @moduledoc false

  require Orb.Ops, as: Ops
  alias Orb.Instruction

  with @behaviour Orb.CustomType do
    @impl Orb.CustomType
    def wasm_type, do: :f64
  end

  for op <- Ops.f64(1) do
    def unquote(op)(a) do
      Instruction.f64(unquote(op), a)
    end
  end

  for op <- Ops.f64(2) do
    def unquote(op)(a, b) do
      Instruction.f64(unquote(op), a, b)
    end
  end
end
