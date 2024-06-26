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
end

defmodule Orb.ToWasm.Context do
  defstruct local_indexes: %{}

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
end
