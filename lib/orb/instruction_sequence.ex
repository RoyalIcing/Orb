defmodule Orb.InstructionSequence do
  defstruct pop_type: nil,
            push_type: nil,
            # control: nil,
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

  require Orb.Ops
  alias Orb.Ops
  alias Orb.Constants

  @doc ~S"""
  Creates a sequence of instructions from a list.

  ## Examples

      iex> Orb.InstructionSequence.new([Orb.InstructionSequence.empty()])
      Orb.InstructionSequence.empty()

      iex> Orb.InstructionSequence.new([Orb.Instruction.i32(:const, 1)])
      %Orb.InstructionSequence{push_type: :i32, body: [
        Orb.Instruction.i32(:const, 1)
      ]}

      iex> Orb.InstructionSequence.new([%Orb.Nop{}])
      %Orb.InstructionSequence{push_type: nil, body: [
        %Orb.Nop{}
      ]}

      iex> Orb.InstructionSequence.new([Orb.Instruction.i32(:const, 1), Orb.Instruction.f32(:const, 2.0)])
      %Orb.InstructionSequence{push_type: {:i32, :f32}, body: [
        Orb.Instruction.i32(:const, 1),
        Orb.Instruction.f32(:const, 2.0),
      ]}

      iex> Orb.InstructionSequence.new([Orb.Control.Return.new(Orb.Instruction.i32(:const, 1))])
      %Orb.InstructionSequence{push_type: nil, body: [
        Orb.Control.Return.new(Orb.Instruction.i32(:const, 1))
      ]}

  """

  def new([instruction_sequence = %__MODULE__{}]), do: instruction_sequence
  # def new([instruction = %{push_type: _}]), do: instruction

  def new(instructions) when is_list(instructions) do
    push_type = do_pop_push_type([], instructions)
    new(push_type, instructions)
  end

  def new(push_type, instructions, opts \\ []) when is_list(instructions) do
    %__MODULE__{
      push_type: push_type,
      body: instructions,
      locals: Keyword.get(opts, :locals, [])
    }
  end

  def empty(), do: %__MODULE__{}

  defp type_to_list(type)
  defp type_to_list(nil), do: []
  defp type_to_list(:nop), do: []
  defp type_to_list(:trap), do: []
  defp type_to_list(type) when is_atom(type), do: [type]
  defp type_to_list(type) when is_tuple(type), do: Tuple.to_list(type) |> Enum.reverse()

  defp do_pop_push_type(stack, instructions)
  defp do_pop_push_type([], []), do: nil
  defp do_pop_push_type([single], []), do: single
  defp do_pop_push_type(stack, []), do: stack |> Enum.reverse() |> List.to_tuple()

  # If there’s a (return …), then nothing becomes pushed to the stack.
  # TODO: check returned stack type against surrounding func’s type.
  # This might have to be comapred again the one stored
  # under Process dict’s Orb.Func.ReturnType entry.
  defp do_pop_push_type(_, [%Orb.Control.Return{} | _]), do: nil

  defp do_pop_push_type([], [head | rest]) do
    case Ops.pop_push_of(head) do
      {nil, push} ->
        do_pop_push_type(type_to_list(push), rest)

      {pop, _push} ->
        raise "Cannot pop #{pop} from empty stack."
    end
  end

  defp do_pop_push_type(stack, [head | rest]) do
    case {Ops.pop_push_of(head), stack} do
      {{pop, push}, [pop | stack]} ->
        do_pop_push_type(type_to_list(push) ++ stack, rest)

      {{nil, push}, stack} ->
        do_pop_push_type(type_to_list(push) ++ stack, rest)

      {{pop, push}, [expected_type | stack]} ->
        cond do
          Ops.is_primitive_type(expected_type) and Ops.to_primitive_type(pop) === expected_type ->
            do_pop_push_type(type_to_list(push) ++ stack, rest)

          true ->
            raise "Cannot pop #{pop} from stack, expected type #{expected_type}."
        end
    end
  end

  @doc ~S"""
  Concatenates instructions in the `second` with those in `first`.

  ## Examples

      iex> Orb.InstructionSequence.concat(Orb.InstructionSequence.empty(), Orb.InstructionSequence.empty())
      Orb.InstructionSequence.empty()

      iex> Orb.InstructionSequence.concat(nil, nil)
      Orb.InstructionSequence.empty()

      iex> Orb.InstructionSequence.concat(Orb.InstructionSequence.new([Orb.Instruction.i32(:const, 1)]), Orb.InstructionSequence.new([Orb.Instruction.f32(:const, 2.0)]))
      %Orb.InstructionSequence{push_type: {:i32, :f32}, body: [
        Orb.Instruction.i32(:const, 1),
        Orb.Instruction.f32(:const, 2.0)
      ]}

      iex> Orb.InstructionSequence.concat(Orb.InstructionSequence.new([Orb.Instruction.i32(:const, 1)]), nil)
      %Orb.InstructionSequence{push_type: :i32, body: [
        Orb.Instruction.i32(:const, 1)
      ]}

  """
  def concat(first, second)

  def concat(nil, nil), do: empty()
  def concat(nil, seq = %__MODULE__{}), do: seq
  def concat(seq = %__MODULE__{}, nil), do: seq

  def concat(first = %__MODULE__{}, second = %__MODULE__{}) do
    new(first.body ++ second.body)
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
            # [Orb.ToWat.to_wat(instruction, indent), "\n"]
            case Instructions.do_wat(instruction, indent) do
              # "" -> ""
              # [] -> ""
              output -> [output, "\n"]
            end
        end
      end
    end
  end

  defimpl Orb.ToWasm do
    def to_wasm(
          %Orb.InstructionSequence{body: instructions},
          options
        ) do
      for instruction <- instructions do
        case instruction do
          %Orb.InstructionSequence{} ->
            to_wasm(instruction, options)

          _ ->
            Orb.ToWasm.to_wasm(instruction, options)
        end
      end
    end
  end

  defimpl Orb.TypeNarrowable do
    def type_narrow_to(
          %Orb.InstructionSequence{push_type: current_type, body: [single]} = seq,
          narrower_type
        ) do
      case Ops.types_compatible?(current_type, narrower_type) do
        true ->
          %{
            seq
            | push_type: narrower_type,
              body: [Orb.TypeNarrowable.type_narrow_to(single, narrower_type)]
          }

        false ->
          seq
      end
    end

    def type_narrow_to(%Orb.InstructionSequence{} = seq, _), do: seq
  end
end
