defmodule Orb.I32.U8.Pointer do
  @moduledoc """
  Custom `Orb.CustomType` for pointer to 8-bit integer (byte) in memory.
  """

  @behaviour Orb.CustomType
  @behaviour Access

  @impl Orb.CustomType
  def wasm_type(), do: :i32

  @impl Orb.CustomType
  def byte_count(), do: 1

  @impl Access
  def fetch(%Orb.VariableReference{} = var_ref, at!: offset) do
    ast = {:i32, :load8_u, Orb.Numeric.Add.optimized(Orb.I32, var_ref, offset)}
    {:ok, ast}
  end
end
