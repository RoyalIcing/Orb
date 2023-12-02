defmodule Orb.Stack do
  @moduledoc false

  defmodule Drop do
    defstruct instruction: nil, count: 0

    require alias Orb.Ops

    def new(%{type: type} = instruction) do
      count = Ops.typeof(instruction) |> Ops.type_stack_count()

      %__MODULE__{
        instruction: instruction,
        count: count
      }
    end

    def new(value) when is_number(value) do
      %__MODULE__{
        instruction: value,
        count: 1
      }
    end

    defimpl Orb.ToWat do
      def to_wat(
            %Orb.Stack.Drop{instruction: instruction, count: count},
            indent
          ) do
        [
          Orb.ToWat.to_wat(instruction, indent),
          "\n",
          for _ <- 1..count do
            [indent, "drop", "\n"]
          end
        ]
      end
    end
  end

  def drop(instruction), do: Drop.new(instruction)
end
