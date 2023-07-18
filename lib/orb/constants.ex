defmodule Orb.Constants do
  @moduledoc false

  defstruct offset: 0xFF, items: []

  def new(items) do
    items = Enum.uniq(items)
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
          ")"
        ]
      end
      |> Enum.intersperse("\n")
    end
  end
end
