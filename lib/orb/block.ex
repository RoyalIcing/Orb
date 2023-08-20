defmodule Orb.Block do
  @moduledoc false

  defstruct [:identifier, :result, :body]

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions
    import Orb.ToWat.Helpers

    def to_wat(
          %Orb.Block{identifier: identifier, result: result, body: body},
          indent
        ) do
      [
        [
          indent,
          "(block $",
          to_string(identifier),
          if(result, do: [" (result ", do_type(result), ")"], else: []),
          "\n"
        ],
        Instructions.do_wat(body, "  " <> indent),
        "\n",
        [indent, ")"]
      ]
    end
  end
end
