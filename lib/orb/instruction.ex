defmodule Orb.Instruction do
  defstruct [:type, :operation, :operands]

  def new(type, operation),
    do: %__MODULE__{type: type, operation: operation, operands: []}

  def new(type, operation, operands) when is_list(operands),
    do: %__MODULE__{
      type: type,
      operation: operation,
      operands: type_check_operands(type, operation, operands)
    }

  def new(type, operation, a),
    do: %__MODULE__{
      type: type,
      operation: operation,
      operands: type_check_operands(type, operation, [a])
    }

  def new(type, operation, a, b),
    do: %__MODULE__{
      type: type,
      operation: operation,
      operands: type_check_operands(type, operation, [a, b])
    }

  def i32(operation), do: new(:i32, operation)
  def i32(operation, a), do: new(:i32, operation, a)
  def i32(operation, a, b), do: new(:i32, operation, a, b)

  def f32(operation), do: new(:f32, operation)
  def f32(operation, a), do: new(:f32, operation, a)
  def f32(operation, a, b), do: new(:f32, operation, a, b)

  def call(f), do: new(:unknown, {:call, f})
  def call(f, args) when is_list(args), do: new(:unknown, {:call, f}, args)
  def typed_call(output_type, f, args) when is_list(args), do: new(output_type, {:call, f}, args)

  def local_get(type, local_name), do: new(type, {:local_get, local_name})

  defp type_check_operands(type, operation, operands) do
    Enum.with_index(operands, &type_check_operand!(type, operation, &1, &2))
    operands
  end

  defp type_check_operand!(:i32, :add, %{type: received_type}, _) do
    case received_type do
      :i32 ->
        nil

      :f32 ->
        raise Orb.TypeCheckError, expected_type: :i32, received_type: :f32

      :unknown ->
        # Ignore
        nil
        # raise "Expected type i32, found unknown type."

      mod ->
        primitive_type = mod.wasm_type()
        primitive_type == :i32 or raise Orb.TypeCheckError, expected_type: :i32, received_type: "#{mod} #{primitive_type}"
    end
  end

  defp type_check_operand!(_output_type, _operation, _operand, _index) do
    nil
  end

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.Instruction{
            operation: {:local_get, local_name},
            operands: []
          },
          indent
        ) do
      [
        indent,
        "(local.get $",
        to_string(local_name),
        ")"
      ]
    end

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
