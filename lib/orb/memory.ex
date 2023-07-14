defmodule Orb.Memory do
  @moduledoc """
  Work with memory.
  """

  defstruct name: "", min: 0, exported?: false

  @doc false
  def from(_)

  def from(nil), do: nil
  def from([]), do: nil

  def from(list) when is_list(list) do
    case Enum.max(list) do
      0 ->
        nil

      min ->
        %__MODULE__{min: min}
    end
  end

  @doc """
  Declare how many 64Kib pages of memory your module needs.

  Can be called multiple times: the highest value is used.
  """
  defmacro pages(min_count) do
    quote do
      @wasm_memory unquote(min_count)
    end
  end

  @doc "Initializes data in memory. In Wat is `(data …)`"
  def initial_data(offset: offset, string: value) do
    %Orb.Data{offset: offset, value: value, nul_terminated: false}
  end

  @doc "Initializes data in memory from a packed `Map`. In Wat is `(data …)`"
  def initial_data_prepacked(packed_map) when is_map(packed_map) do
    for {_key, %{offset: offset, string: string}} <- packed_map do
      initial_data(offset: offset, string: string)
    end
  end

  @doc """
  Load value of `type` from memory `address`.

  ```elixir
  Memory.load!(I32, 0x100)
  ```
  """
  def load!(type, address) do
    type =
      if function_exported?(type, :wasm_type, 0) do
        type.wasm_type()
      else
        raise "You passed a Orb type module #{type} that does not implement wasm_type/0."
      end

    {type, :load, address}
  end

  @doc """
  Store `value` of `type` at memory `address`.

  ```elixir
  Memory.store!(I32, 0x100, 42)
  ```
  """
  def store!(type, address, value) do
    type =
      if function_exported?(type, :wasm_type, 0) do
        type.wasm_type()
      else
        raise "You passed a Orb type module #{type} that does not implement wasm_type/0."
      end

    {type, :store, address, value}
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Memory{min: min}, indent) do
      [
        indent,
        ~S{(memory (export "memory")},
        case min do
          nil -> []
          int -> [" ", to_string(int)]
        end,
        ~S{)},
        "\n"
      ]
    end
  end
end
