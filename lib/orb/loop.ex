defmodule Orb.Loop do
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
        Instructions.do_wat(body, "  " <> indent),
        "\n",
        [indent, ")"]
      ]
    end
  end
end
