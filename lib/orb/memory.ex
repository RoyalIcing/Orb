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
  defmacro initial_data!(offset, value) do
    quote bind_quoted: [offset: offset, value: value] do
      @wasm_section_data %Orb.Data{offset: offset, value: value, nul_terminated: false}
    end
  end

  @doc """
  Load value of `type` from memory `address`.

  ```elixir
  Memory.load!(I32, 0x100)
  Memory.load!(I32.U8, 0x100)
  ```

  ## Examples

      iex> use Orb
      iex> Memory.load!(I32, 0x100) |> Orb.to_wat()
      "(i32.load (i32.const 256))"
      iex> Memory.load!(I32.U8, 0x100) |> Orb.to_wat()
      "(i32.load8_u (i32.const 256))"
      iex> Memory.load!(I32, 0x100, align: 2) |> Orb.to_wat()
      "(i32.load align=2 (i32.const 256))"
      iex> Memory.load!(I32, 0x100, align: 4) |> Orb.to_wat()
      "(i32.load align=4 (i32.const 256))"

      iex> use Orb
      iex> Memory.load!(I32, 0x100, align: 3)
      ** (ArgumentError) malformed alignment 3

      iex> use Orb
      iex> Memory.load!(I32, 0x100, align: 8)
      ** (ArgumentError) alignment 8 must not be larger than natural 4

      iex> use Orb
      iex> Memory.load!(I32.U8, 0x100, align: 2)
      ** (ArgumentError) alignment 2 must not be larger than natural 1
  ```
  """
  def load!(type, address, opts \\ []) do
    Orb.Memory.Load.new(type, address, opts)
  end

  @doc """
  Store `value` of `type` at memory `address`.

  ```elixir
  Memory.store!(I32, 0x100, 42)
  Memory.store!(I32.U8, 0x100, ?a)
  ```

  ## Examples

      iex> use Orb
      iex> Memory.store!(I32, 0x100, 42) |> Orb.to_wat()
      "(i32.store (i32.const 256) (i32.const 42))"
      iex> Memory.store!(I32.U8, 0x100, ?a) |> Orb.to_wat()
      "(i32.store8 (i32.const 256) (i32.const 97))"
      iex> Memory.store!(I32, 0x100, 42, align: 2) |> Orb.to_wat()
      "(i32.store align=2 (i32.const 256) (i32.const 42))"
      iex> Memory.store!(I32, 0x100, 42, align: 4) |> Orb.to_wat()
      "(i32.store align=4 (i32.const 256) (i32.const 42))"

      iex> use Orb
      iex> Memory.store!(I32, 0x100, 42, align: 3)
      ** (ArgumentError) malformed alignment 3

      iex> use Orb
      iex> Memory.store!(I32, 0x100, 42, align: 8)
      ** (ArgumentError) alignment 8 must not be larger than natural 4

      iex> use Orb
      iex> Memory.store!(I32.U8, 0x100, 42, align: 2)
      ** (ArgumentError) alignment 2 must not be larger than natural 1
  """
  def store!(type, address, value, opts \\ []) do
    Orb.Memory.Store.new(type, address, value, opts)
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
