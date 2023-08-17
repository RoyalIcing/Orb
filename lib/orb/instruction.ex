defmodule Orb.Instruction do
  defstruct [:output_type, :operation, :operands]

  def new(output_type, operation),
    do: %__MODULE__{output_type: output_type, operation: operation, operands: []}

  def new(output_type, operation, operands) when is_list(operands),
    do: %__MODULE__{output_type: output_type, operation: operation, operands: operands}

  def new(output_type, operation, a),
    do: %__MODULE__{output_type: output_type, operation: operation, operands: [a]}

  def new(output_type, operation, a, b),
    do: %__MODULE__{output_type: output_type, operation: operation, operands: [a, b]}

  def i32(operation), do: new(:i32, operation)
  def i32(operation, a), do: new(:i32, operation, a)
  def i32(operation, a, b), do: new(:i32, operation, a, b)

  def f32(operation), do: new(:f32, operation)
  def f32(operation, a), do: new(:f32, operation, a)
  def f32(operation, a, b), do: new(:f32, operation, a, b)

  def call(f), do: new(:unknown, {:call, f})
  def call(f, args) when is_list(args), do: new(:unknown, {:call, f}, args)
  def typed_call(output_type, f, args) when is_list(args), do: new(output_type, {:call, f}, args)

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.Instruction{
            operation: {:call, f},
            operands: operands
          },
          indent
        ) do
      [
        indent,
        "(call $",
        to_string(f),
        for(operand <- operands, do: [" ", Instructions.do_wat(operand)]),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            output_type: output_type,
            operation: operation,
            operands: operands
          },
          indent
        ) do
      [
        indent,
        "(",
        to_string(output_type),
        ".",
        to_string(operation),
        for(operand <- operands, do: [" ", Instructions.do_wat(operand)]),
        ")"
      ]
    end
  end
end
