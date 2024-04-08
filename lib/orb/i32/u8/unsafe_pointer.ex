defmodule Orb.I32.U8.UnsafePointer do
  @moduledoc """
  Custom `Orb.CustomType` for pointer to 8-bit integer (byte) in memory.
  """

  alias Orb.{Memory, I32, VariableReference}

  with @behaviour Orb.CustomType do
    @impl Orb.CustomType
    def wasm_type, do: :i32

    @impl Orb.CustomType
    def load_instruction, do: :load8_u
  end

  def memory_alignment, do: 1

  with @behaviour Access do
    @impl Access
    def fetch(%VariableReference{} = var_ref, at!: offset) do
      ast = Memory.load!(I32.U8, Orb.Numeric.Add.optimized(I32, var_ref, offset))
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
