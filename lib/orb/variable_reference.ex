defmodule Orb.VariableReference do
  @moduledoc false

  defmodule Global do
    defstruct [:identifier, :type]

    def set(%__MODULE__{identifier: identifier, type: type}, new_value) do
      Orb.Instruction.Global.Set.new(type, identifier, new_value)
    end

    def set_from_stack(%__MODULE__{identifier: identifier, type: type}) do
      Orb.Instruction.Global.Set.new(type, identifier, Orb.Stack.Pop.new(type))
    end

    defimpl Orb.ToWat do
      def to_wat(%Orb.VariableReference.Global{identifier: identifier}, indent) do
        [indent, "(global.get $", to_string(identifier), ?)]
      end
    end
  end

  defmodule Local do
    defstruct [:identifier, :type]

    def set(%__MODULE__{identifier: identifier, type: type}, new_value) do
      Orb.Instruction.local_set(type, identifier, new_value)
    end

    def set_from_stack(%__MODULE__{identifier: identifier, type: type}) do
      Orb.Instruction.local_set(type, identifier, Orb.Stack.Pop.new(type))
    end

    defimpl Orb.ToWat do
      def to_wat(%Orb.VariableReference.Local{identifier: identifier}, indent) do
        [indent, "(local.get $", to_string(identifier), ?)]
      end
    end

    defimpl Orb.ToWasm do
      import Orb.Leb

      def to_wasm(%Orb.VariableReference.Local{identifier: identifier}, context) do
        import Orb.Leb

        [0x20, leb128_u(Orb.ToWasm.Context.fetch_local_index!(context, identifier))]
      end
    end
  end

  defstruct [:entries, :push_type, :pop_type]

  def global(identifier, type) do
    %__MODULE__{
      entries: [%Global{identifier: identifier, type: type}],
      push_type: type
    }
  end

  def local(identifier, type) do
    %__MODULE__{
      entries: [%Local{identifier: identifier, type: type}],
      push_type: type
    }
  end

  def set(
        %__MODULE__{entries: entries},
        new_value
      ) do
    new_value =
      case new_value do
        new_value when is_tuple(new_value) ->
          Tuple.to_list(new_value)

        new_value when is_list(new_value) ->
          new_value

        new_value ->
          List.wrap(new_value)
      end

    for {entry, value} <- Enum.zip(entries, new_value) do
      entry.__struct__.set(entry, value)
    end
    |> Orb.InstructionSequence.new()
  end

  def as_set(%__MODULE__{entries: entries}) when length(entries) === 1 do
    Orb.InstructionSequence.new(
      nil,
      for entry <- entries do
        entry.__struct__.set_from_stack(entry)
      end,
      pop_type: hd(entries).type
    )
  end

  with @behaviour Access do
    # some_str[:ptr]
    @impl Access
    def fetch(
          %__MODULE__{entries: [%Local{identifier: local_name, type: Orb.Str}]},
          :ptr
        ) do
      {:ok,
       %__MODULE__{
         entries: [
           %Local{
             identifier: "#{local_name}.ptr",
             type: I32.UnsafePointer
           }
         ]
       }}
    end

    # some_str[:size]
    @impl Access
    def fetch(
          %__MODULE__{entries: [%Local{identifier: local_name, type: Orb.Str}]},
          :size
        ) do
      {:ok,
       %__MODULE__{
         entries: [
           %Local{
             identifier: "#{local_name}.size",
             type: I32
           }
         ]
       }}
    end

    @impl Access
    def fetch(
          %__MODULE__{entries: [%Local{type: mod}]} = var_ref,
          key
        ) do
      mod.fetch(var_ref, key)
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

  defimpl Orb.ToWat do
    def to_wat(%Orb.VariableReference{entries: entries}, indent) do
      for entry <- entries do
        Orb.ToWat.to_wat(entry, indent)
      end
    end
  end

  defimpl Orb.ToWasm do
    def to_wasm(
          %Orb.VariableReference{entries: entries},
          context
        ) do
      for entry <- entries do
        Orb.ToWasm.to_wasm(entry, context)
      end
    end
  end
end
