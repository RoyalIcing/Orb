defmodule Orb.Instruction do
  defstruct [:type, :operation, :operands]

  def new(type, operation), do: %__MODULE__{type: type, operation: operation, operands: []}
  def new(type, operation, a), do: %__MODULE__{type: type, operation: operation, operands: [a]}
  def new(type, operation, a, b), do: %__MODULE__{type: type, operation: operation, operands: [a, b]}

  def i32(operation), do: new(:i32, operation)
  def i32(operation, a), do: new(:i32, operation, a)
  def i32(operation, a, b), do: new(:i32, operation, a, b)

  def f32(operation), do: new(:f32, operation)
  def f32(operation, a), do: new(:f32, operation, a)
  def f32(operation, a, b), do: new(:f32, operation, a, b)

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.Instruction{
            type: type,
            operation: operation,
            operands: operands
          },
          indent
        ) do
      [
        indent,
        "(",
        to_string(type),
        ".",
        to_string(operation),
        for(operand <- operands, do: [" ", Instructions.do_wat(operand)]),
        ")"
      ]
    end
  end
end
