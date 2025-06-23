defmodule Orb.Memory do
  @moduledoc """
  Work with memory: load, store, declare pages & initial data.
  """

  defstruct name: "", min: 0, import_or_export: {:export, "memory"}

  def __sum_min(wasm_memory) do
    for {:min_add, page_count} <- wasm_memory, reduce: 0 do
      total -> total + page_count
    end
  end

  @doc false
  def new(page_definitions, constants)

  # def new(nil), do: nil
  # def new([]), do: nil

  def new(list, %{offset: constants_offset, byte_size: constants_byte_size}) when is_list(list) do
    bytes_per_page = page_byte_size()

    requested_page_count = __sum_min(list)

    constants_page_count =
      if constants_byte_size > 0 do
        div(constants_offset + constants_byte_size + bytes_per_page - 1, bytes_per_page)
      else
        0
      end

    total_page_count = requested_page_count + constants_page_count

    import_or_export =
      Enum.find(list, {:export, "memory"}, fn
        {:export, _name} -> true
        {:import, _namespace, _name} -> true
        _ -> false
      end)

    case total_page_count do
      0 ->
        nil

      min ->
        %__MODULE__{min: min, import_or_export: import_or_export}
    end
  end

  defmacro import(namespace, name) do
    quote bind_quoted: [namespace: namespace, name: name] do
      @wasm_memory {:import, namespace, name}
    end
  end

  defmacro export(name) do
    quote bind_quoted: [name: name] do
      @wasm_memory {:export, name}
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
      start_offset = unquote(__MODULE__).__sum_min(@wasm_memory)
      @wasm_memory {:min_add, unquote(page_count)}
      # FIXME: the idea is this returns the page offset, but constants will push this down
      # making this offset incorrect.
      start_offset
    end
  end

  @doc "Initializes data in memory. In Wat is `(data …)`"
  defmacro initial_data!(offset, value) do
    quote bind_quoted: [offset: offset, value: value] do
      @wasm_section_data %Orb.Data{offset: offset, value: value}
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
  A convenience for swapping two values of `type` at addresses `address_a` and `address_b` in memory.

  Bubble sort is an example of an algorithm which uses a swap.
  """
  def swap!(type, address_a, address_b, opts \\ []) do
    alias Orb.I32

    opts = Keyword.take(opts, [:align])

    Orb.InstructionSequence.new(nil, [
      Orb.Instruction.Const.wrap(:i32, address_b),
      load!(type, address_a, opts),
      Orb.Instruction.Const.wrap(:i32, address_a),
      load!(type, address_b, opts),
      store!(type, Orb.Stack.pop(I32), Orb.Stack.pop(I32), opts),
      store!(type, Orb.Stack.pop(I32), Orb.Stack.pop(I32), opts)
    ])
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

  @doc """
  Copies a region of memory from a source memory location to a destination memory location.

  Takes three i32 parameters:
  - `dest_index`: The destination memory offset to copy to
  - `src_index`: The source memory offset to copy from  
  - `length`: The number of bytes to copy

  https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Memory/Copy

  ```elixir
  Memory.copy!(dest_index, src_index, length)
  ```
  """
  def copy!(dest_index, src_index, length) do
    Orb.Instruction.memory_copy(dest_index, src_index, length)
  end

  @doc """
  Fills a region of memory with a specified byte value.

  Takes three i32 parameters:
  - `dest_index`: The memory offset to start filling at
  - `value`: The byte value (0-255) to fill with
  - `length`: The number of bytes to fill

  https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Memory/Fill

  ```elixir
  Memory.fill!(dest_index, value, length)
  ```
  """
  def fill!(dest_index, value, length) do
    Orb.Instruction.memory_fill(dest_index, value, length)
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Memory{min: min, import_or_export: import_or_export}, indent) do
      [
        indent,
        case import_or_export do
          {:import, namespace, name} ->
            [
              ~S|(import "|,
              to_string(namespace),
              ~S|" "|,
              to_string(name),
              ~S|" (memory|
            ]

          {:export, name} ->
            [
              ~S|(memory (export "|,
              to_string(name),
              ~S|")|
            ]
        end,
        case min do
          nil -> []
          int -> [" ", to_string(int)]
        end,
        case import_or_export do
          {:import, _namespace, _name} -> ~S|))|
          _ -> ~S|)|
        end,
        "\n"
      ]
    end
  end

  defimpl Orb.ToWasm do
    import Orb.Leb

    def to_wasm(
          %Orb.Memory{
            min: min
          },
          _context
        ) do
      [
        case min do
          nil -> [0x0, 0x0]
          min when min >= 0 -> [0x0, leb128_u(min)]
        end
      ]
    end
  end
end
