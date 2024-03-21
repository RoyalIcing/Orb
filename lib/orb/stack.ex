defmodule Orb.Stack do
  @moduledoc false

  defmodule Drop do
    defstruct instruction: nil, count: 0

    require alias Orb.Ops

    def new(instruction) do
      type = Ops.typeof(instruction)
      count = Ops.type_stack_count(type)

      if count === 0 do
        raise ArgumentError,
          message: "Cannot drop #{type}."
      end

      %__MODULE__{
        instruction: instruction,
        count: count
      }
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
