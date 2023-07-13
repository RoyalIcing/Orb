defmodule Orb.Block do
  defstruct [:identifier, :result, :body]

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.Block{identifier: identifier, result: result, body: body},
          indent
        ) do
      [
        [
          indent,
          "(block $",
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
