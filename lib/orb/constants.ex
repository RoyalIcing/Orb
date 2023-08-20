defmodule Orb.Constants do
  @moduledoc false

  # TODO: decide on non-arbitrary offset, and document it.
  defstruct offset: 0xFF, items: [], lookup_table: []

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

  def lookup(constants, value) do
    {_, memory_offset} = List.keyfind!(constants.lookup_table, value, 0)
    %NulTerminatedString{memory_offset: memory_offset, string: value}
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
