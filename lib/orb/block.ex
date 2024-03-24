defmodule Orb.Block do
  @moduledoc false

  defstruct [:identifier, :push_type, :body]

  defimpl Orb.ToWat do
    alias Orb.ToWat.Helpers

    def to_wat(
          %Orb.Block{identifier: identifier, push_type: push_type, body: body},
          indent
        ) do
      [
        [
          indent,
          "(block $",
          to_string(identifier),
          if(push_type, do: [" (result ", Helpers.do_type(push_type), ")"], else: []),
          "\n"
        ],
        Orb.ToWat.to_wat(body, "  " <> indent),
        [indent, ")"]
      ]
    end
  end

  defmodule Branch do
    defstruct [:identifier, :if]

    defimpl Orb.ToWat do
      def to_wat(
            %Orb.Block.Branch{identifier: identifier, if: nil},
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
            %Orb.Block.Branch{identifier: identifier, if: condition},
            indent
          ) do
        [
          Orb.ToWat.to_wat(condition, indent),
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
