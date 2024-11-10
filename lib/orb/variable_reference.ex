defmodule Orb.VariableReference do
  @moduledoc false

  defstruct [:global_or_local, :identifier, :push_type]

  alias Orb.Instruction

  def global(identifier, type) do
    %__MODULE__{global_or_local: :global, identifier: identifier, push_type: type}
  end

  def local(identifier, type) do
    %__MODULE__{global_or_local: :local, identifier: identifier, push_type: type}
  end

  def set(
        %__MODULE__{global_or_local: :local, identifier: identifier, push_type: type},
        new_value
      ) do
    Instruction.local_set(type, identifier, new_value)
  end

  def as_set(%__MODULE__{global_or_local: :local, identifier: identifier, push_type: type}) do
    Instruction.local_set(type, identifier)
  end

  @behaviour Access

  @impl Access
  # TODO: I think this should only live on custom types like UnsafePointer
  def fetch(
        %__MODULE__{global_or_local: :local, identifier: _identifier, push_type: :i32} = ref,
        at: offset
      ) do
    ast = Instruction.i32(:load, Instruction.i32(:add, ref, offset))
    {:ok, ast}
  end

  def fetch(
        %__MODULE__{global_or_local: :local, identifier: _identifier, push_type: mod} = ref,
        key
      ) do
    mod.fetch(ref, key)
  end

  @impl Access
  def get_and_update(_data, _key, _function) do
    raise UndefinedFunctionError, module: __MODULE__, function: :get_and_update, arity: 3
  end

  @impl Access
  def pop(_data, _key) do
    raise UndefinedFunctionError, module: __MODULE__, function: :pop, arity: 2
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.VariableReference{global_or_local: :global, identifier: identifier}, indent) do
      [indent, "(global.get $", to_string(identifier), ?)]
    end

    def to_wat(%Orb.VariableReference{global_or_local: :local, identifier: identifier}, indent) do
      [indent, "(local.get $", to_string(identifier), ?)]
    end
  end

  defimpl Orb.ToWasm do
    import Orb.Leb

    def to_wasm(
          %Orb.VariableReference{global_or_local: :local, identifier: identifier},
          context
        ) do
      [0x20, leb128_u(Orb.ToWasm.Context.fetch_local_index!(context, identifier))]
    end
  end
end
