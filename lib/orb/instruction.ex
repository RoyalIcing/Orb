defmodule Orb.Instruction do
  defstruct [:type, :operation, :operands]

  require Orb.Ops, as: Ops
  alias Orb.Constants

  @types [:i32, :i64, :f64, :f32, :local_effect, :global_effect, :unknown_effect]

  def new(type, operation, operands \\ [])

  def new(type, operation, operands) when is_list(operands) and type in @types,
    do: %__MODULE__{
      type: type,
      operation: operation,
      operands: type_check_operands!(type, operation, operands)
    }

  def new(Elixir.Integer, operation, operands) do
    raise "Can’t create an instruction for Elixir.Integer, need concrete type like Orb.I32."
  end

  def new(Elixir.Float, operation, operands) do
    raise "Can’t create an instruction for Elixir.Float, need concrete type like Orb.F32."
  end

  def new(nil, operation, operands) do
    raise "Can’t create an instruction for nil, need :unknown instead. #{inspect(operation)} #{inspect(operands)}"
  end

  def new(type, operation, operands) when is_list(operands) and is_atom(type) do
    Code.ensure_loaded!(type)

    # TODO: check that this implements custom type.
    # _ = type.wasm_type()
    if function_exported?(type, :wasm_type, 0) do
      type.wasm_type()
    else
      raise "You passed a Orb type module #{type} that does not implement wasm_type/0. #{inspect(operation)} #{inspect(operands)}"
    end

    %__MODULE__{
      type: type,
      operation: operation,
      # TODO: type check custom types.
      operands: operands |> Enum.map(&Constants.expand_if_needed/1)
    }
  end

  def wrap_constant!(type, value)

  def wrap_constant!(Elixir.Integer, value) when is_number(value),
    do: raise("Need concrete type not Elixir.Integer for constants.")

  def wrap_constant!(Elixir.Float, value) when is_number(value),
    do: raise("Need concrete type not Elixir.Float for constants.")

  def wrap_constant!(type, value) when is_number(value),
    do: %__MODULE__{
      type: type,
      operation: :const,
      operands: [value]
    }

  def wrap_constant!(type, %{type: type} = value), do: value

  def wrap_constant!(type_a, %{type: type_b} = value) do
    case Ops.types_compatible?(type_a, type_b) do
      true ->
        value

      false ->
        raise Orb.TypeCheckError,
          expected_type: type_a,
          received_type: type_b,
          instruction_identifier: "#{type_a}.const"
    end
  end

  def i32(operation), do: new(:i32, operation)
  def i32(operation, a) when is_list(a), do: new(:i32, operation, a)
  def i32(operation, a), do: new(:i32, operation, [a])
  def i32(operation, a, b), do: new(:i32, operation, [a, b])

  def i64(operation), do: new(:i64, operation)
  def i64(operation, a) when is_list(a), do: new(:i64, operation, a)
  def i64(operation, a), do: new(:i64, operation, [a])
  def i64(operation, a, b), do: new(:i64, operation, [a, b])

  def f32(operation), do: new(:f32, operation)
  def f32(operation, a) when is_list(a), do: new(:f32, operation, a)
  def f32(operation, a), do: new(:f32, operation, [a])
  def f32(operation, a, b), do: new(:f32, operation, [a, b])

  def call(f), do: new(:unknown_effect, {:call, f})
  def call(f, args) when is_list(args), do: new(:unknown_effect, {:call, f}, args)
  def typed_call(output_type, f, args) when is_list(args), do: new(output_type, {:call, f}, args)

  def local_get(type, local_name), do: new(type, {:local_get, local_name})
  def local_tee(type, local_name, value), do: new(type, {:local_tee, local_name}, [value])

  def local_set(type, local_name, value),
    do: new(:local_effect, {:local_set, local_name, type}, [value])

  def global_get(type, global_name), do: new(type, {:global_get, global_name})

  def global_set(type, global_name, value),
    do: new(:global_effect, {:global_set, global_name, type}, [value])

  def memory_size(), do: new(:i32, {:memory, :size}, [])
  def memory_grow(value), do: new(:i32, {:memory, :grow}, [value])

  defp type_check_operands!(type, operation, operands) do
    operands
    |> Enum.with_index(fn operand, index ->
      operand = Constants.expand_if_needed(operand)

      case type_check_operand!(type, operation, operand, index) do
        nil ->
          operand

        value ->
          value
      end
    end)
  end

  defp type_check_operand!(type, op, number, param_index)
       when is_number(number) and type in [:i32, :i64, :f32] and is_atom(op) do
    expected_type = Ops.param_type!(type, op, param_index)

    received_type =
      cond do
        # is_integer(number) -> :i32
        is_integer(number) -> Elixir.Integer
        is_float(number) -> :f32
      end

    # type_check_operand!(type, op, %{type: received_type}, param_index)
    types_must_match!(expected_type, received_type, "#{type}.#{op}")

    case expected_type do
      Elixir.Integer ->
        number

      Elixir.Float ->
        number

      expected_type ->
        wrap_constant!(expected_type, number)
    end
  end

  defp type_check_operand!(:i32, op, %{type: received_type} = operand, param_index)
       when is_atom(op) do
    expected_type = Ops.i32_param_type!(op, param_index)

    types_must_match!(expected_type, received_type, "i32.#{op}")

    wrap_constant!(expected_type, operand)
  end

  defp type_check_operand!(:i32, op, operand, param_index) when is_atom(op) do
    expected_type = Ops.i32_param_type!(op, param_index)

    wrap_constant!(expected_type, operand)
  end

  defp type_check_operand!(:i64, op, %{type: received_type} = operand, param_index)
       when is_atom(op) do
    expected_type = Ops.i64_param_type!(op, param_index)

    types_must_match!(expected_type, received_type, "i64.#{op}")

    wrap_constant!(expected_type, operand)
  end

  defp type_check_operand!(:i64, op, operand, param_index) when is_atom(op) do
    expected_type = Ops.i64_param_type!(op, param_index)

    wrap_constant!(expected_type, operand)
  end

  defp type_check_operand!(
         :local_effect,
         {:local_set, local_name, expected_type},
         operand,
         0
       ) do
    received_type = get_operand_type(operand)

    types_must_match!(expected_type, received_type, "local.set $#{local_name}")

    operand
  end

  defp type_check_operand!(
         :global_effect,
         {:global_set, global_name, expected_type},
         operand,
         0
       ) do
    received_type = get_operand_type(operand)

    types_must_match!(expected_type, received_type, "global.set $#{global_name}")

    operand
  end

  defp type_check_operand!(_type, _operation, operand, _index) do
    operand
  end

  defp get_operand_type(%{type: received_type}), do: received_type
  defp get_operand_type(n) when is_integer(n), do: Elixir.Integer
  defp get_operand_type(n) when is_float(n), do: Elixir.Float

  defp types_must_match!(same, same, _instruction_identifier), do: nil

  defp types_must_match!(expected_type, received_type, instruction_identifier) do
    case received_type do
      :unknown ->
        # Ignore
        nil

      type ->
        Ops.types_compatible?(type, expected_type) or
          raise Orb.TypeCheckError,
            expected_type: expected_type,
            received_type: type,
            instruction_identifier: instruction_identifier

        # nil
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
            operation: {:memory, memory_op},
            operands: operands
          },
          indent
        ) do
      [
        indent,
        "(memory.",
        to_string(memory_op),
        for(operand <- operands, do: [" ", Instructions.do_wat(operand)]),
        ")"
      ]
    end

    def to_wat(
          %Orb.Instruction{
            type: type,
            operation: :const,
            operands: [number]
          },
          indent
        ) do
      [
        indent,
        "(",
        to_string(Ops.to_primitive_type(type)),
        ".const ",
        to_string(number),
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
