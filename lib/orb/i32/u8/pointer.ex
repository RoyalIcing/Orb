defmodule Orb.I32.U8.Pointer do
  @behaviour Orb.Type
  @behaviour Access

  @impl Orb.Type
  def wasm_type(), do: :i32

  @impl Orb.Type
  def byte_count(), do: 1

  @impl Access
  def fetch(%Orb.VariableReference{} = var_ref, at!: offset) do
    ast = {:i32, :load8_u, Orb.Numeric.Add.optimized(Orb.I32, var_ref, offset)}
    {:ok, ast}
  end
end
