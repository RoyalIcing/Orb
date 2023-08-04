defmodule Orb.Constants do
  @moduledoc false

  # TODO: decide on non-arbitrary offset, and document it.
  defstruct offset: 0xFF, items: []

  def from_attribute(items) do
    items =
      items
      # Module attributes accumulate by prepending
      |> Enum.reverse()
      |> List.flatten()
      |> Enum.uniq()

    %__MODULE__{items: items}
  end

  def to_keylist(%__MODULE__{offset: offset, items: items}) do
    {lookup_table, _} =
      items
      |> Enum.map_reduce(offset, fn string, offset ->
        {{string, offset}, offset + byte_size(string) + 1}
      end)

    lookup_table
  end

  def to_map(%__MODULE__{} = receiver) do
    receiver |> to_keylist() |> Map.new()
  end

  def resolve(_constants, {:i32_const_string, _strptr, _string} = value) do
    value
  end

  def resolve(constants, value) do
    {:i32_const_string, Map.fetch!(constants, value), value}
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Constants{} = constants, indent) do
      for {string, offset} <- Orb.Constants.to_keylist(constants) do
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
