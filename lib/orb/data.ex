defmodule Orb.Data do
  @moduledoc false

  defstruct [:offset, :value, :nul_terminated]

  defimpl Orb.ToWat do
    def to_wat(%Orb.Data{offset: offset, value: value, nul_terminated: nul_terminated}, indent) do
      [
        indent,
        "(data (i32.const ",
        to_string(offset),
        ") ",
        ?",
        value |> String.replace(~S["], ~S[\"]) |> String.replace("\n", ~S"\n"),
        if(nul_terminated, do: ~S"\00", else: []),
        ?",
        ")"
      ]
    end
  end
end
