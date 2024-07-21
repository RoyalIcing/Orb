defprotocol Orb.ToWasm do
  @doc "Protocol for converting to WebAssembly binary format (.wasm)"
  def to_wasm(data, options)
end

defmodule Orb.ToWasm.Helpers do
  @moduledoc false

  import Orb.Leb

  def sized(bytes) do
    bytes = IO.iodata_to_binary(bytes)
    [byte_size(bytes) |> uleb128(), bytes]
  end

  def vec(items) when is_list(items) do
    [
      length(items) |> uleb128(),
      items
    ]
  end

  def to_wasm_type(nil), do: raise("nil is not a valid type")
  def to_wasm_type(:i32), do: 0x7F
  def to_wasm_type(:i64), do: 0x7E
  def to_wasm_type(:f32), do: 0x7D
  def to_wasm_type(:f64), do: 0x7C
  def to_wasm_type(:v128), do: 0x7B

  def to_wasm_type(custom_type) when is_atom(custom_type),
    do: Orb.Ops.to_primitive_type(custom_type) |> to_wasm_type()
end

defmodule Orb.ToWasm.Context do
  defstruct local_indexes: %{}, loop_indexes: %{}

  def new(), do: %__MODULE__{}

  def set_local_get_types(context = %__MODULE__{}, local_types) do
    local_indexes =
      Enum.with_index(local_types)
      |> Map.new(fn {{id, type}, index} -> {id, %{index: index, type: type}} end)

    # Map.new(
    #   for {{id, type}, index} <- Enum.with_index(local_types),
    #       do: {id, %{index: index, type: type}}
    # )

    put_in(context.local_indexes, local_indexes)
  end

  def fetch_local_index!(context = %__MODULE__{}, local_identifier) do
    entry = Map.fetch!(context.local_indexes, local_identifier)
    entry.index
  end

  def register_loop_identifier(context = %__MODULE__{loop_indexes: loop_indexes}, loop_identifier)
      when not is_map_key(loop_indexes, loop_identifier) do
    next_index = map_size(loop_indexes)
    loop_indexes = Map.put(loop_indexes, loop_identifier, next_index)
    %__MODULE__{context | loop_indexes: loop_indexes}
  end

  def fetch_loop_identifier_index!(%__MODULE__{loop_indexes: loop_indexes}, loop_identifier)
      when is_map_key(loop_indexes, loop_identifier) do
    Map.fetch!(loop_indexes, loop_identifier)
  end
end
