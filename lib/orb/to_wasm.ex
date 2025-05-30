defprotocol Orb.ToWasm do
  @doc """
  Protocol for converting to WebAssembly binary format (.wasm)

  There’s a helpful table / cheatsheet of instruction opcodes here: https://pengowray.github.io/wasm-ops/
  """
  def to_wasm(data, options)
end

defmodule Orb.ToWasm.Error do
  @moduledoc """
  Exception struct for ToWasm conversion errors.
  """
  defexception [:message, :exception]

  @impl Exception
  def exception(opts) do
    exception = Keyword.fetch!(opts, :exception)
    value = Keyword.fetch!(opts, :value)
    msg = Exception.message(exception) <> " | Source AST: #{inspect(value)}"
    %__MODULE__{message: msg, exception: exception}
  end
end

defmodule Orb.ToWasm.Helpers do
  @moduledoc false

  import Orb.Leb
  require Orb.Ops

  def sized(bytes) do
    size = IO.iodata_length(bytes)
    [leb128_u(size), bytes]
  end

  def vec(items) when is_list(items) do
    [
      length(items) |> leb128_u(),
      items
    ]
  end

  @doc """
  Converts Elixir types to WebAssembly type bytes.
  """
  def to_wasm_type(nil), do: raise("nil is not a valid type")
  def to_wasm_type(:i32), do: 0x7F
  def to_wasm_type(:i64), do: 0x7E
  def to_wasm_type(:f32), do: 0x7D
  def to_wasm_type(:f64), do: 0x7C
  def to_wasm_type(:v128), do: 0x7B

  def to_wasm_type(custom_type) when is_atom(custom_type) do
    Orb.Ops.to_primitive_type(custom_type) |> to_wasm_type()
  end

  @doc """
  Converts types to WebAssembly block type encoding.

  For primitive types, returns the same as to_wasm_type/1.
  For custom types, looks up the type index in the context.
  """
  def to_block_type(nil, _context), do: raise("nil is not a valid type")
  def to_block_type(:i32, _context), do: 0x7F
  def to_block_type(:i64, _context), do: 0x7E
  def to_block_type(:f32, _context), do: 0x7D
  def to_block_type(:f64, _context), do: 0x7C
  def to_block_type(:v128, _context), do: 0x7B

  def to_block_type(custom_type, context) when is_atom(custom_type) do
    primitive_type = Orb.Ops.to_primitive_type(custom_type)

    case primitive_type do
      primitive_type when Orb.Ops.is_primitive_type(primitive_type) ->
        to_wasm_type(custom_type)

      tuple when is_tuple(tuple) ->
        case Orb.ToWasm.Context.get_custom_type_index(context, custom_type) do
          nil ->
            raise "Must declare custom type using Orb.types([#{inspect(custom_type)}]). Registered types: #{inspect(context.custom_types_to_indexes)}"

          index when is_integer(index) ->
            # Type indexes should be unsigned
            leb128_u(index)
        end
    end
  end
end

defmodule Orb.ToWasm.Context do
  @moduledoc """
  Context for managing name-to-index mappings during WASM compilation.

  Tracks global variables, functions, custom types, local variables, and loop identifiers
  to resolve references during binary generation.
  """
  defstruct global_names_to_indexes: %{},
            func_names_to_indexes: %{},
            custom_types_to_indexes: %{},
            local_indexes: %{},
            loop_indexes: %{}

  def new(), do: %__MODULE__{}

  def set_custom_type_index_lookup(%__MODULE__{} = context, custom_types_to_indexes)
      when is_map(custom_types_to_indexes) do
    %__MODULE__{context | custom_types_to_indexes: custom_types_to_indexes}
  end

  def get_custom_type_index(%__MODULE__{} = context, custom_type) do
    identifier =
      cond do
        is_atom(custom_type) and function_exported?(custom_type, :type_name, 0) ->
          custom_type.type_name()

        true ->
          # Fallback to the custom_type itself as identifier
          custom_type
      end

    Map.get(context.custom_types_to_indexes, identifier)
  end

  def set_global_name_index_lookup(%__MODULE__{} = context, global_names_to_indexes)
      when is_map(global_names_to_indexes) do
    %__MODULE__{context | global_names_to_indexes: global_names_to_indexes}
  end

  def fetch_global_index!(%__MODULE__{} = context, global_name) do
    Map.fetch!(context.global_names_to_indexes, global_name)
  end

  def set_func_name_index_lookup(%__MODULE__{} = context, func_names_to_indexes)
      when is_map(func_names_to_indexes) do
    %__MODULE__{context | func_names_to_indexes: func_names_to_indexes}
  end

  def fetch_func_index!(%__MODULE__{} = context, func_name) do
    Map.fetch!(context.func_names_to_indexes, func_name)
  end

  def set_local_get_types(%__MODULE__{} = context, local_types) do
    local_indexes =
      Enum.with_index(local_types)
      |> Map.new(fn {{id, type}, index} -> {id, %{index: index, type: type}} end)

    put_in(context.local_indexes, local_indexes)
  end

  def fetch_local_index!(%__MODULE__{} = context, local_identifier) do
    entry = Map.fetch!(context.local_indexes, local_identifier)
    entry.index
  end

  @doc """
  Registers a loop identifier in the context for later reference.

  Assigns an index to the loop identifier for use in branch instructions.
  Index 0 is reserved for the function itself.
  """
  def register_loop_identifier(%__MODULE__{loop_indexes: loop_indexes} = context, loop_identifier)
      when not is_map_key(loop_indexes, loop_identifier) do
    # Index 0 is the function itself, so we start at 1.
    next_index = map_size(loop_indexes)

    key =
      case loop_identifier do
        nil -> {nil, next_index}
        other -> other
      end

    loop_indexes = Map.put(loop_indexes, key, next_index)
    %__MODULE__{context | loop_indexes: loop_indexes}
  end

  @doc """
  Retrieves the relative index for a loop identifier.

  WebAssembly uses relative indexing where 0 refers to the innermost block/loop.
  This function converts the stored absolute index to the correct relative index.

  Example with 2 loops (a: 0, b: 1):
  - For loop 'b': 2 - 1 - 1 = 0 (innermost)
  - For loop 'a': 2 - 0 - 1 = 1 (outer)
  """
  def fetch_loop_identifier_index!(%__MODULE__{loop_indexes: loop_indexes}, loop_identifier)
      when is_map_key(loop_indexes, loop_identifier) do
    index = Map.fetch!(loop_indexes, loop_identifier)
    map_size(loop_indexes) - index - 1
  end
end
