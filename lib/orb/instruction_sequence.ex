defmodule Orb.InstructionSequence do
  defstruct type: :unknown_effect,
            body: [],
            contains:
              %{
                # locals_effected: %{},
                # globals_effected: %{},
                # unknown_effect: false,
                # i32: false,
                # i64: false,
                # f32: false,
                # f64: false
              },
            locals: []

  alias Orb.Ops
  alias Orb.Constants

  def new([instruction_sequence = %__MODULE__{}]), do: instruction_sequence

  def new([instruction]) do
    new(Ops.typeof(instruction, :primitive), [instruction])
  end

  def new(instructions) when is_list(instructions) do
    type = do_get_type(nil, instructions)
    new(type, instructions)
    # raise "Inference of result type via reduce is unimplemented for now."
  end

  def new(type, instructions, opts \\ []) when is_list(instructions) do
    %__MODULE__{
      type: type,
      body: instructions,
      locals: Keyword.get(opts, :locals, [])
    }
  end

  def empty(), do: %__MODULE__{type: :nop, body: []}

  def do_get_type(type, instructions)
  def do_get_type(nil, []), do: :nop
  def do_get_type(type, []), do: type
  def do_get_type(nil, [head | rest]), do: Ops.typeof(head) |> do_get_type(rest)

  def do_get_type(type, [head | rest]) do
    type =
      cond do
        head |> Ops.typeof() |> Ops.types_compatible?(type) ->
          type

        true ->
          :unknown_effect
      end

    do_get_type(type, rest)
  end

  @doc ~S"""
  Concatenates instructions in the `second` with those in `first`.

  ## Examples

      iex> Orb.InstructionSequence.concat(Orb.InstructionSequence.empty(), Orb.InstructionSequence.empty())
      %Orb.InstructionSequence{type: :nop, body: []}

      iex> Orb.InstructionSequence.concat(Orb.InstructionSequence.new([Orb.Instruction.i32(:const, 1)]), Orb.InstructionSequence.new([Orb.Instruction.f32(:const, 2.0)]))
      %Orb.InstructionSequence{type: :f32, body: [
        Orb.Instruction.i32(:const, 1),
        Orb.Instruction.f32(:const, 2.0)
      ]}

  """
  def concat(first, second) do
    %__MODULE__{
      type: second.type,
      body: first.body ++ second.body
    }
  end

  def expand(%__MODULE__{} = func) do
    body = func.body |> Enum.map(&Constants.expand_if_needed/1)
    %{func | body: body}
  end

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.InstructionSequence{body: instructions},
          indent
        ) do
      for instruction <- instructions do
        case instruction do
          %Orb.InstructionSequence{} ->
            to_wat(instruction, indent)

          _ ->
            [Instructions.do_wat(instruction, indent), "\n"]
        end
      end
    end
  end

  defimpl Orb.TypeNarrowable do
    def type_narrow_to(
          %Orb.InstructionSequence{type: current_type, body: [single]} = seq,
          narrower_type
        ) do
      case Ops.types_compatible?(current_type, narrower_type) do
        true ->
          %{
            seq
            | type: narrower_type,
              body: [Orb.TypeNarrowable.type_narrow_to(single, narrower_type)]
          }

        false ->
          seq
      end
    end

    def type_narrow_to(%Orb.InstructionSequence{} = seq, _), do: seq
  end
end
