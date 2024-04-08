defmodule Orb.I32.UnsafePointer do
  @moduledoc """
  Custom `Orb.CustomType` for pointer to a 32-bit integer in memory.

  It is aligned to 4 bytes or 32-bits, so you can only load/store at memory offsets divisible by 4.
  """

  with @behaviour Orb.CustomType do
    @impl Orb.CustomType
    def wasm_type, do: :i32
  end

  def memory_alignment, do: 4

  with @behaviour Access do
    alias Orb.{Memory, I32, VariableReference}

    @impl Access
    def fetch(%VariableReference{} = var_ref, at!: offset) do
      address =
        offset
        |> then(&Orb.Numeric.Multiply.optimized(I32, &1, 4))
        |> then(&Orb.Numeric.Add.optimized(I32, &1, var_ref))

      ast = Memory.load!(I32, address)
      {:ok, ast}
    end

    @impl Access
    def get_and_update(_data, _key, _function) do
      raise UndefinedFunctionError, module: __MODULE__, function: :get_and_update, arity: 3
    end

    @impl Access
    def pop(_data, _key) do
      raise UndefinedFunctionError, module: __MODULE__, function: :pop, arity: 2
    end
  end
end
