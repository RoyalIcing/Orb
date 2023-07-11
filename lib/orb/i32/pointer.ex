defmodule Orb.I32.Pointer do
  @behaviour Orb.Type
  @behaviour Access

  @impl Orb.Type
  def wasm_type(), do: :i32

  @impl Orb.Type
  def byte_count(), do: 4

  @impl Access
  def fetch(%Orb.VariableReference{} = var_ref, at!: offset) do
    address = offset |> Orb.I32.Multiply.neutralize(4) |> Orb.I32.Add.neutralize(var_ref)
    ast = {:i32, :load, address}
    {:ok, ast}
  end
end
