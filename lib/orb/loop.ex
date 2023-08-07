defmodule Orb.Loop do
  @moduledoc false

  defstruct [:identifier, :result, :body]

  alias Orb.ToWat.Instructions

  defimpl Orb.ToWat do
    def to_wat(
          %Orb.Loop{identifier: identifier, result: result, body: body},
          indent
        ) do
      [
        [
          indent,
          "(loop $",
          to_string(identifier),
          if(result, do: " (result #{result})", else: []),
          "\n"
        ],
        Enum.map(body, &[Instructions.do_wat(&1, "  " <> indent), "\n"]),
        [indent, ")"]
      ]
    end
  end
end
