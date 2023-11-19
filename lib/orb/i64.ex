defmodule Orb.I64 do
  @moduledoc """
  Type for 64-bit integer.
  """

  require alias Orb.Ops
  alias Orb.Instruction

  @behaviour Orb.CustomType

  @impl Orb.CustomType
  def wasm_type(), do: :i64

  # TODO: is the byte count of the pointer, or the items?
  # I think this should actually be removed from Orb.CustomType
  @impl Orb.CustomType
  def byte_count(), do: 8

  for op <- Ops.i64(1) do
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
