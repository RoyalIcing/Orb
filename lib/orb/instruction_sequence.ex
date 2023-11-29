defmodule Orb.InstructionSequence do
  defstruct type: :unknown_effect,
            body: [],
            contains: %{
              locals_effected: %{},
              globals_effected: %{},
              unknown_effect: false,
              i32: false,
              i64: false,
              f32: false,
              f64: false
            }

  alias Orb.Ops

  def new([instruction]) do
    new(Ops.extract_type(instruction), [instruction])
  end

  def new(instructions) when is_list(instructions) do
    new(:unknown_effect, instructions)
    # raise "Inference of result type via reduce is unimplemented for now."
  end

  def new(type, instructions) when is_list(instructions) do
    %__MODULE__{
      type: type,
      body: instructions
    }
  end

  defmacro from_block(block) do
    alias __MODULE__

    case block do
      nil ->
        nil |> Macro.escape()

      {:__block__, _meta, block_items} ->
        quote do: InstructionSequence.new(:unknown_effect, unquote(block_items))

      single ->
        quote do: InstructionSequence.new(Ops.extract_type(unquote(single)), [unquote(single)])
    end
  end

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.InstructionSequence{body: instructions},
          indent
        ) do
      for instruction <- instructions do
        Instructions.do_wat(instruction, indent)
      end
    end
  end
end
