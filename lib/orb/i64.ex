defmodule Orb.I64 do
  @moduledoc """
  Type for 64-bit integer.
  """

  alias require Orb.Ops
  alias Orb.Instruction

  with @behaviour Orb.CustomType do
    @impl Orb.CustomType
    def wasm_type(), do: :i64
  end

  for op <- Ops.i64(1) do
    @doc Ops.doc(:i64, op)
    def unquote(op)(a) do
      Instruction.i64(unquote(op), a)
    end
  end

  for op <- Ops.i64(2) do
    case op do
      :and ->
        def band(a, b) do
          Instruction.i64(:and, a, b)
        end

      _ ->
        def unquote(op)(a, b) do
          Instruction.i64(unquote(op), a, b)
        end
    end
  end
end
