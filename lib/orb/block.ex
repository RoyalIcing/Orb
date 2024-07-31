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

  defimpl Orb.ToWasm do
    import Orb.ToWasm.Helpers

    def to_wasm(%Orb.Block{identifier: identifier, push_type: push_type, body: body}, context) do
      context = Orb.ToWasm.Context.register_loop_identifier(context, to_string(identifier))

      [
        0x02,
        if(push_type, do: to_block_type(push_type, context), else: 0x40),
        Orb.ToWasm.to_wasm(body, context),
        0x0B
      ]
    end
  end

  defmodule Branch do
    @moduledoc false
    defstruct identifier: nil, if: nil, body: nil

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

    defimpl Orb.ToWasm do
      alias Orb.Leb

      def to_wasm(
            %Orb.Block.Branch{identifier: identifier, if: nil},
            context
          ) do
        index = Orb.ToWasm.Context.fetch_loop_identifier_index!(context, to_string(identifier))

        [0x0C, Leb.leb128_u(index)]
      end

      def to_wasm(
            %Orb.Block.Branch{identifier: identifier, if: condition},
            context
          ) do
        index = Orb.ToWasm.Context.fetch_loop_identifier_index!(context, to_string(identifier))

        [
          Orb.ToWasm.to_wasm(condition, context),
          0x0D,
          Leb.leb128_u(index)
        ]
      end
    end
  end
end
