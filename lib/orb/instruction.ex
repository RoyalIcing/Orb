defmodule Orb.Instruction do
  defstruct [:type, :operation, :operands]

  require Orb.Ops, as: Ops
  alias Orb.Constants

  def new(type, operation),
    do: %__MODULE__{type: type, operation: operation, operands: []}

  def new(type, operation, operands) when is_list(operands),
    do: %__MODULE__{
      type: type,
      operation: operation,
      operands: type_check_operands(type, operation, operands)
    }

  def i32(operation), do: new(:i32, operation)
  def i32(operation, a) when is_list(a), do: new(:i32, operation, a)
  def i32(operation, a), do: new(:i32, operation, [a])
  def i32(operation, a, b), do: new(:i32, operation, [a, b])

  def f32(operation), do: new(:f32, operation)
  def f32(operation, a) when is_list(a), do: new(:f32, operation, a)
  def f32(operation, a), do: new(:f32, operation, [a])
  def f32(operation, a, b), do: new(:f32, operation, [a, b])

  def call(f), do: new(:unknown, {:call, f})
  def call(f, args) when is_list(args), do: new(:unknown, {:call, f}, args)
  def typed_call(output_type, f, args) when is_list(args), do: new(output_type, {:call, f}, args)

  def local_get(type, local_name), do: new(type, {:local_get, local_name})
  def local_tee(type, local_name, value), do: new(type, {:local_tee, local_name}, [value])

  def local_set(type, local_name, value),
    do: new(:local_effect, {:local_set, local_name, type}, [value])

  def global_get(type, global_name), do: new(type, {:global_get, global_name})

  def global_set(type, global_name, value),
    do: new(:global_effect, {:global_set, global_name, type}, [value])

  defp type_check_operands(type, operation, operands) do
    operands = operands |> Enum.map(&Constants.expand_if_needed/1)

    Enum.with_index(operands, &type_check_operand!(type, operation, &1, &2))

    operands
  end

  defp type_check_operand!(type, op, number, param_index) when is_number(number) do
    received_type =
      cond do
        is_integer(number) -> :i32
        is_float(number) -> :f32
      end

    type_check_operand!(type, op, %{type: received_type}, param_index)
  end

  defp type_check_operand!(:i32, op, %{type: received_type}, param_index) when is_atom(op) do
    expected_type = Ops.i32_param_type!(op, param_index)

    types_must_match!(expected_type, received_type)
  end

  defp type_check_operand!(
         :local_effect,
         {:local_set, _, expected_type},
         %{type: received_type},
         0
       ) do
    types_must_match!(expected_type, received_type)
  end

  defp type_check_operand!(
         :global_effect,
         {:global_set, _, expected_type},
         %{type: received_type},
         0
       ) do
    types_must_match!(expected_type, received_type)
  end

  defp type_check_operand!(:i32, op, _operand, param_index) when is_atom(op) do
    Ops.i32_param_type!(op, param_index)
  end

  defp type_check_operand!(_type, _operation, _operand, _index) do
    nil
  end

  defp types_must_match!(same, same), do: nil

  defp types_must_match!(expected_type, received_type) do
    case received_type do
      :unknown ->
        # Ignore
        nil

      type ->
        Ops.types_compatible?(type, expected_type) or
          raise Orb.TypeCheckError,
            expected_type: expected_type,
            received_type: type
    end
  end

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
            operation: {:local_get, local_name},
            operands: []
          },
          indent
        ) do
      [indent, "(local.get $", to_string(local_name), ")"]
    end

    def to_wat(
          %Orb.Instruction{
            operation: {:local_tee, local_name},
            operands: operands
          },
          indent
        ) do
      [
        for(operand <- operands, do: [indent, Instructions.do_wat(operand), "\n"]),
        indent,
        "(local.tee $",
        to_string(local_name),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            operation: {:local_set, local_name, _},
            operands: operands
          },
          indent
        ) do
      [
        for(operand <- operands, do: [indent, Instructions.do_wat(operand), "\n"]),
        indent,
        "(local.set $",
        to_string(local_name),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            operation: {:global_get, global_name},
            operands: []
          },
          indent
        ) do
      [indent, "(global.get $", to_string(global_name), ")"]
    end

    def to_wat(
          %Orb.Instruction{
            operation: {:global_set, global_name, _},
            operands: operands
          },
          indent
        ) do
      [
        for(operand <- operands, do: [indent, Instructions.do_wat(operand), "\n"]),
        indent,
        "(global.set $",
        to_string(global_name),
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
