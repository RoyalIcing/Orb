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
    case Enum.sum(list) do
      0 ->
        nil

      min ->
        %__MODULE__{min: min}
    end
  end

  @page_byte_size 64 * 1024
  def page_byte_size(), do: @page_byte_size

  @doc """
  Declare how many 64Kib pages of memory your module needs.

  Can be called multiple times, with each summed up.

  Returns the previous page count, which can be used as a start offset.
  """
  defmacro pages(page_count) do
    quote do
      start_offset = Enum.sum(@wasm_memory)
      @wasm_memory unquote(page_count)
      start_offset
    end
  end

  @doc "Initializes data in memory. In Wat is `(data …)`"
  def initial_data(offset: offset, string: value) do
    %Orb.Data{offset: offset, value: value, nul_terminated: false}
  end

  @doc """
  Load value of `type` from memory `address`.

  ```elixir
  Memory.load!(I32, 0x100)
  Memory.load!(I32.U8, 0x100)
  ```
  """
  def load!(type, address) do
    primitive_type = Orb.CustomType.resolve!(type)

    load_instruction =
      if function_exported?(type, :load_instruction, 0) do
        type.load_instruction()
      else
        :load
      end

    Orb.Instruction.new(primitive_type, load_instruction, [address])
  end

  @doc """
  Store `value` of `type` at memory `address`.

  ```elixir
  Memory.store!(I32, 0x100, 42)
  Memory.store!(I32.U8, 0x100, ?a)
  ```
  """
  def store!(type, offset, value) do
    # TODO: add `align` arg https://webassembly.github.io/spec/core/bikeshed/#syntax-instr-memory
    primitive_type = Orb.CustomType.resolve!(type)

    load_instruction =
      if function_exported?(type, :load_instruction, 0) do
        type.load_instruction()
      else
        :load
      end

    store_instruction =
      case load_instruction do
        :load8_u -> :store8
        :load8_s -> :store8
        :load -> :store
      end

    Orb.Instruction.memory_store(primitive_type, store_instruction, offset: offset, value: value)
  end

  @doc """
  Returns the number of pages the memory instance currently has. Each page is 64KiB.

  To increase the number of pages call `grow!/1`.

  https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Memory/Size

  ```elixir
  Memory.size()
  ```
  """
  def size() do
    Orb.Instruction.memory_size()
  end

  @doc """
  Increases the size of the memory instance by a specified number of pages. Each page is 64KiB.

  Note: only `0` and `1` are supported in today’s runtimes.

  It returns the previous size of memory in pages if the operation was successful, or returns -1 if the operation failed.

  https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Memory/Grow

  ```elixir
  Memory.grow!(1)
  ```
  """
  def grow!(delta) do
    Orb.Instruction.memory_grow(delta)
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
