defmodule Orb.Constants do
  @moduledoc false

  @default_offset 0xFF

  # TODO: decide on non-arbitrary offset, and document it.
  # Enscripten starts at offset 1024 (0x400).
  defstruct offset: @default_offset, items: [], lookup_table: [], byte_size: 0

  def __begin(start_offset \\ @default_offset) do
    tid = Process.get(__MODULE__)

    if not is_nil(tid) do
      raise "Must not nest Orb.Constants scopes."
    end

    tid = :ets.new(__MODULE__, [:set, :private])
    :ets.insert(tid, {:start_offset, start_offset})
    :ets.insert(tid, {:offset, start_offset})
    Process.put(__MODULE__, tid)
    nil
  end

  defp lookup_offset(string) when is_binary(string) do
    case Process.get(__MODULE__) do
      nil ->
        :not_compiling

      tid ->
        upsert_offset(tid, string)
    end
  end

  defp safe_ets_lookup(tid, key) do
    # When OTP 26 is minimum version, can be replaced with:
    # :ets.lookup_element(tid, key, 2, nil)

    case :ets.lookup(tid, key) do
      [{^key, value}] -> value
      _ -> nil
    end
  end

  defp upsert_offset(tid, string) do
    case safe_ets_lookup(tid, string) do
      offset when is_integer(offset) ->
        {:ok, offset}

      nil ->
        count = byte_size(string) + 1
        new_offset = :ets.update_counter(tid, :offset, {2, count})
        offset = new_offset - count
        :ets.insert(tid, {string, offset})
        {:ok, offset}
    end
  end

  # @matcher :ets.fun2ms(fn {string, offset} when is_binary(string) ->
  #   {string, 0xFF + offset}
  # end)

  def __read() do
    tid = Process.get(__MODULE__)

    if is_nil(tid) do
      raise "Must be called within a Orb.Constants scope."
    end

    # matcher = :ets.fun2ms(fn {string, offset} when is_binary(string) ->
    #   {string, offset}
    # end)

    matcher = [{{:"$1", :"$2"}, [is_binary: :"$1"], [{{:"$1", :"$2"}}]}]
    lookup_table = :ets.select(tid, matcher)

    # start_offset = :ets.update_counter(tid, :start_offset, {2, 0})
    start_offset = safe_ets_lookup(tid, :start_offset)
    last_offset = safe_ets_lookup(tid, :offset)
    byte_size = last_offset - start_offset

    # Sort by offsets, lowest to largest
    lookup_table = List.keysort(lookup_table, 1, :asc)

    # entries = :ets.match_object(__MODULE__, {:"$0", :"$1"})

    %__MODULE__{offset: start_offset, items: [], lookup_table: lookup_table, byte_size: byte_size}
  end

  def __cleanup() do
    if tid = Process.delete(__MODULE__) do
      :ets.delete(tid)
    end
  end

  @doc """
  Creates a ordered lookup table of deduplicated constants.

  ## Examples

      iex> Orb.Constants.from_attribute([
      ...>  "abc",
      ...>  "def",
      ...>  "abc",
      ...> ])
      %Orb.Constants{offset: 255, items: ["abc", "def"], byte_size: 8, lookup_table: [{"abc", 255}, {"def", 259}]}

  """
  def from_attribute(items, offset \\ 0xFF) do
    items =
      items
      # Module attributes accumulate by prepending
      |> Enum.reverse()
      |> List.flatten()
      |> Enum.uniq()

    {lookup_table, last_offset} =
      items
      |> Enum.map_reduce(offset, fn string, offset ->
        {{string, offset}, offset + byte_size(string) + 1}
      end)

    byte_size = last_offset - offset

    %__MODULE__{offset: offset, items: items, lookup_table: lookup_table, byte_size: byte_size}
  end

  def expand_if_needed(value)
  def expand_if_needed(value) when is_binary(value), do: expand_string!(value)
  def expand_if_needed(value) when is_list(value), do: :lists.map(&expand_if_needed/1, value)
  def expand_if_needed(value) when is_struct(value, Orb.IfElse), do: Orb.IfElse.expand(value)
  def expand_if_needed(nil), do: nil

  def expand_if_needed(value) when is_atom(value) do
    str = value |> Atom.to_string() |> expand_string!()
    str.memory_offset
  end

  # Handles Orb.InstructionSequence or anything with a `body`
  def expand_if_needed(%_{body: _} = struct) do
    body = expand_if_needed(struct.body)
    %{struct | body: body}
  end

  def expand_if_needed(value), do: value

  defp expand_string!(string) when is_binary(string) do
    case lookup_offset(string) do
      {:ok, offset} ->
        %Orb.Str{memory_offset: offset, string: string}

      :not_compiling ->
        raise "Orb: Can only lookup strings during compilation."
    end
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Constants{lookup_table: []}, _), do: []

    def to_wat(%Orb.Constants{lookup_table: lookup_table, byte_size: byte_size}, indent) do
      [
        [indent, "(; constants #{byte_size} bytes ;)\n"],
        for {string, offset} <- lookup_table do
          %Orb.Data{offset: offset, value: string}
          |> Orb.ToWat.to_wat(indent)
        end
      ]
    end
  end

  defimpl Orb.ToWasm do
    def to_wasm(
          %Orb.Constants{lookup_table: lookup_table},
          context
        ) do
      for {string, offset} <- lookup_table do
        [
          # active
          0x0,
          Orb.Instruction.Const.new(:i32, offset) |> Orb.ToWasm.to_wasm(context),
          # end opcode
          0x0B,
          Orb.ToWasm.Helpers.sized(string)
        ]
      end
    end
  end
end
