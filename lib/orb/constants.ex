defmodule Orb.Constants do
  @moduledoc false

  # TODO: decide on non-arbitrary offset, and document it.
  defstruct offset: 0xFF, items: [], lookup_table: []

  def __begin(start_offset \\ 0xFF) do
    tid = Process.get(__MODULE__)

    if not is_nil(tid) do
      raise "Must not nest Orb.Constants scopes."
    end

    # try do
    #   :ets.delete(__MODULE__)
    # rescue
    #   ArgumentError -> nil
    # end

    # __MODULE__ = :ets.new(__MODULE__, [:set, :private, :named_table])
    tid = :ets.new(__MODULE__, [:set, :private])
    :ets.insert(tid, {:offset, start_offset})
    Process.put(__MODULE__, tid)
    nil
  end

  defp lookup_offset(string) when is_binary(string) do
    case Process.get(__MODULE__) do
      nil ->
        :not_compiling

      tid ->
        case :ets.lookup_element(tid, string, 2, nil) do
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
  end

  # @matcher :ets.fun2ms(fn {string, offset} when is_binary(string) ->
  #   {string, 0xFF + offset}
  # end)

  def __done() do
    tid = Process.get(__MODULE__)

    if is_nil(tid) do
      raise "Must be called within a Orb.Constants scope."
    end

    Process.delete(__MODULE__)

    # matcher = :ets.fun2ms(fn {string, offset} when is_binary(string) ->
    #   {string, offset}
    # end)

    matcher = [{{:"$1", :"$2"}, [is_binary: :"$1"], [{{:"$1", :"$2"}}]}]
    lookup_table = :ets.select(tid, matcher)
    :ets.delete(tid)

    # entries = :ets.match_object(__MODULE__, {:"$0", :"$1"})

    %__MODULE__{offset: 0xFF, items: [], lookup_table: lookup_table}
  end

  def from_attribute(items, offset \\ 0xFF) do
    items =
      items
      # Module attributes accumulate by prepending
      |> Enum.reverse()
      |> List.flatten()
      |> Enum.uniq()

    {lookup_table, _} =
      items
      |> Enum.map_reduce(offset, fn string, offset ->
        {{string, offset}, offset + byte_size(string) + 1}
      end)

    %__MODULE__{offset: offset, items: items, lookup_table: lookup_table}
  end

  defmodule NulTerminatedString do
    defstruct memory_offset: nil, string: nil, type: Orb.I32.String

    defimpl Orb.ToWat do
      def to_wat(%Orb.Constants.NulTerminatedString{memory_offset: memory_offset}, indent) do
        [
          indent,
          "(i32.const ",
          to_string(memory_offset),
          ")"
        ]
      end
    end
  end

  # def lookup(constants, value) do
  #   {_, memory_offset} = List.keyfind!(constants.lookup_table, value, 0)
  #   %NulTerminatedString{memory_offset: memory_offset, string: value}
  # end

  def expand_if_needed(value)
  def expand_if_needed(value) when is_binary(value), do: expand_string!(value)
  def expand_if_needed(value), do: value

  defp expand_string!(string) when is_binary(string) do
    case lookup_offset(string) do
      {:ok, offset} ->
        %NulTerminatedString{memory_offset: offset, string: string}

      :not_compiling ->
        raise "Can only lookup strings during compilation."
    end
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Constants{lookup_table: lookup_table}, indent) do
      for {string, offset} <- lookup_table do
        [
          indent,
          "(data (i32.const ",
          to_string(offset),
          ") ",
          ?",
          string |> String.replace(~S["], ~S[\"]) |> String.replace("\n", ~S"\n"),
          ?",
          ")\n"
        ]
      end
    end
  end
end
