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
    defstruct pop_type: nil, push_type: nil, count: 0

    require alias Orb.Ops

    def new(type) do
      count = type |> Ops.type_stack_count()

      %__MODULE__{
        # This instruction struct is weird. It essentially does nothing
        # as WebAssembly automatically pops from the stack if it needs.
        # So we pretend to pop and push the same type: effectively a nop.
        # Other parts of the system need to see the type, say
        # `Orb.Instruction.get_operand_type/1` so we fulfill that contract.
        pop_type: type,
        push_type: type,
        count: count
      }
    end

    defimpl Orb.ToWat do
      alias Orb.ToWat.Helpers

      # def to_wat(%Orb.Stack.Pop{}, _), do: []
      def to_wat(%Orb.Stack.Pop{pop_type: type}, _), do: ["(;", Helpers.do_type(type), ";)"]
    end
  end

  @doc """
  Executes the passed instruction and immediately drops its result(s) from the stack, effectively ignoring the resulting value.
  """
  def drop(instruction), do: Drop.new(instruction)

  @doc """
  Pops the last value from the stack, useful for assigning it to a local.
  """
  def pop(type), do: Pop.new(type)

  @doc """
  Pushes a value onto the current stack.
  """
  def push(value)

  def push(%Orb.Instruction{operation: {:local_set, identifier, type}, operands: [value]}) do
    Orb.Instruction.local_tee(type, identifier, value)
  end

  def push(%Orb.Instruction{} = instruction), do: instruction
  def push(%Orb.VariableReference{} = ref), do: ref

  @doc """
  Push value then run the block. Useful for when you mutate a variable but want its previous value.
  """
  defmacro push(value, do: block) do
    quote do
      Orb.InstructionSequence.concat(
        Orb.InstructionSequence.new([unquote(value)]),
        Orb.InstructionSequence.new(unquote(Orb.__get_block_items(block)))
      )
    end
  end
end
