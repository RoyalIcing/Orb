defprotocol Orb.ToWasm do
  @doc """
  Protocol for converting to WebAssembly binary format (.wasm)

  There’s a helpful table / cheatsheet of instruction opcodes here: https://pengowray.github.io/wasm-ops/
  """
  def to_wasm(data, options)
end

defmodule Orb.ToWasm.Helpers do
  @moduledoc false

  import Orb.Leb

  def sized(bytes) do
    # TODO: use IO.iodata_length/1 to save allocating binary
    bytes = IO.iodata_to_binary(bytes)
    [byte_size(bytes) |> leb128_u(), bytes]
  end

  def vec(items) when is_list(items) do
    [
      length(items) |> leb128_u(),
      items
    ]
  end

  def to_wasm_type(nil), do: raise("nil is not a valid type")
  def to_wasm_type(:i32), do: 0x7F
  def to_wasm_type(:i64), do: 0x7E
  def to_wasm_type(:f32), do: 0x7D
  def to_wasm_type(:f64), do: 0x7C
  def to_wasm_type(:v128), do: 0x7B

  def to_wasm_type(tuple) when is_tuple(tuple) do
    [
      0x7B,
      leb128_u(tuple_size(tuple)),
      tuple
      |> Tuple.to_list()
      |> Enum.map(&to_wasm_type/1)
    ]
  end

  def to_wasm_type(custom_type) when is_atom(custom_type) do
    Orb.Ops.to_primitive_type(custom_type) |> to_wasm_type()
  end
end

defmodule Orb.ToWasm.Context do
  defstruct global_names_to_indexes: %{},
            func_names_to_indexes: %{},
            local_indexes: %{},
            loop_indexes: %{}

  def new(), do: %__MODULE__{}

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

    # Map.new(
    #   for {{id, type}, index} <- Enum.with_index(local_types),
    #       do: {id, %{index: index, type: type}}
    # )

    put_in(context.local_indexes, local_indexes)
  end

  def fetch_local_index!(%__MODULE__{} = context, local_identifier) do
    entry = Map.fetch!(context.local_indexes, local_identifier)
    entry.index
  end

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

  def fetch_loop_identifier_index!(%__MODULE__{loop_indexes: loop_indexes}, loop_identifier)
      when is_map_key(loop_indexes, loop_identifier) do
    index = Map.fetch!(loop_indexes, loop_identifier)
    map_size(loop_indexes) - index - 1

    # 0
    # a: 0
    # b: 1
    # 2 - 1 - 1 = 0
    # 2 - 0 - 1 = 1
  end
end
