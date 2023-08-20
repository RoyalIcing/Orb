defmodule Orb.Loop do
  @moduledoc false

  defstruct [:identifier, :result, :body]

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions
    import Orb.ToWat.Helpers

    def to_wat(
          %Orb.Loop{identifier: identifier, result: result, body: body},
          indent
        ) do
      [
        [
          indent,
          "(loop $",
          to_string(identifier),
          if(result, do: [" (result ", do_type(result), ")"], else: []),
          "\n"
        ],
        Enum.map(body, &[Instructions.do_wat(&1, "  " <> indent), "\n"]),
        [indent, ")"]
      ]
    end
  end

  defmodule Branch do
    defstruct [:identifier, :if]

    defimpl Orb.ToWat do
      def to_wat(
            %Orb.Loop.Branch{identifier: identifier, if: nil},
            indent
          ) do
        [
          indent,
          "(br $",
          to_string(identifier),
          ")"
        ]
      end

      def to_wat(
            %Orb.Loop.Branch{identifier: identifier, if: condition},
            indent
          ) do
        [
          indent,
          Orb.ToWat.Instructions.do_wat(condition),
          "\n",
          indent,
          "(br_if $",
          to_string(identifier),
          ")"
        ]
      end
    end
  end
end
