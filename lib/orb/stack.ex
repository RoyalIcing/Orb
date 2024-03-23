defmodule Orb.Stack do
  @moduledoc false

  defmodule Drop do
    defstruct instruction: nil, count: 0, pop_type: nil, push_type: nil

    require alias Orb.Ops

    def new(instruction) do
      case Ops.pop_push_of(instruction) do
        {nil, nil} ->
          raise ArgumentError,
            message: "Cannot drop instruction pushing nothing to the stack."

        {nil, type} when is_atom(type) ->
          %__MODULE__{
            instruction: instruction,
            count: 1
          }

        {nil, type} when is_tuple(type) ->
          %__MODULE__{
            instruction: instruction,
            count: tuple_size(type)
          }

        {pop, _} ->
          raise ArgumentError,
            message: "Cannot drop instruction that is already popping #{pop} from the stack."
      end
    end

    defimpl Orb.ToWat do
      def to_wat(
            %Orb.Stack.Drop{instruction: instruction, count: count},
            indent
          ) do
        [
          Orb.ToWat.to_wat(instruction, indent),
          for _ <- 1..count do
            ["\n", indent, "drop"]
          end
        ]
      end
    end
  end

  defmodule Pop do
    defstruct type: nil, count: 0

    require alias Orb.Ops

    def new(type) do
      count = type |> Ops.type_stack_count()

      %__MODULE__{
        type: type,
        count: count
      }
    end

    defimpl Orb.ToWat do
      def to_wat(%Orb.Stack.Pop{}, _), do: []
    end
  end

  def drop(instruction), do: Drop.new(instruction)
  def pop(type), do: Pop.new(type)
end
