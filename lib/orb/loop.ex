defmodule Orb.Loop do
  @moduledoc false

  defstruct identifier: nil, push_type: nil, body: nil

  defimpl Orb.ToWat do
    import Orb.ToWat.Helpers

    def to_wat(
          %Orb.Loop{identifier: identifier, push_type: result, body: body},
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
        Orb.ToWat.to_wat(body, "  " <> indent),
        [indent, ")"]
      ]
    end
  end

  defimpl Orb.ToWasm do
    import Orb.ToWasm.Helpers

    def to_wasm(
          %Orb.Loop{
            identifier: identifier,
            push_type: result,
            body: body
          },
          context
        ) do
      context = Orb.ToWasm.Context.register_loop_identifier(context, identifier)

      [
        [0x03, if(result, do: to_block_type(result, context), else: [0x40])],
        Orb.ToWasm.to_wasm(body, context),
        0x0B
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
            %Orb.Loop.Branch{identifier: identifier, if: nil},
            context
          ) do
        index = Orb.ToWasm.Context.fetch_loop_identifier_index!(context, identifier)

        [0x0C, Leb.leb128_u(index)]
      end

      def to_wasm(
            %Orb.Loop.Branch{identifier: identifier, if: condition},
            context
          ) do
        index = Orb.ToWasm.Context.fetch_loop_identifier_index!(context, identifier)

        [
          Orb.ToWasm.to_wasm(condition, context),
          0x0D,
          Leb.leb128_u(index)
        ]
      end
    end
  end
end
