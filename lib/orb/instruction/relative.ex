defmodule Orb.Instruction.Relative do
  @moduledoc false
  defstruct push_type: :i32, input_type: nil, operation: nil, lhs: nil, rhs: nil

  def new(primitive_type, operation, lhs, rhs)

  def new(primitive_type, operation, lhs, rhs)
      when primitive_type in ~w(i32 i64)a and
             operation in ~w(eq ne lt_u lt_s gt_u gt_s le_u le_s ge_u ge_s)a do
    %__MODULE__{
      input_type: primitive_type,
      operation: operation,
      lhs: lhs,
      rhs: rhs
    }
  end

  def new(primitive_type, operation, lhs, rhs)
      when primitive_type in ~w(f32 f64)a and operation in ~w(eq ne lt gt le ge)a do
    %__MODULE__{
      input_type: primitive_type,
      operation: operation,
      lhs: lhs,
      rhs: rhs
    }
  end

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.Instruction.Relative{
            input_type: input_type,
            operation: operation,
            lhs: lhs,
            rhs: rhs
          },
          indent
        ) do
      [
        indent,
        "(",
        to_string(input_type),
        ".",
        to_string(operation),
        " ",
        Instructions.do_wat(lhs),
        " ",
        Instructions.do_wat(rhs),
        ")"
      ]
    end
  end

  defimpl Orb.ToWasm do
    def to_wasm(
          %Orb.Instruction.Relative{
            input_type: input_type,
            operation: operation,
            lhs: lhs,
            rhs: rhs
          },
          options
        ) do
      [
        Orb.Instruction.Const.wrap(input_type, lhs) |> Orb.ToWasm.to_wasm(options),
        Orb.Instruction.Const.wrap(input_type, rhs) |> Orb.ToWasm.to_wasm(options),
        do_operation(input_type, operation)
      ]
    end

    defp do_operation(:i32, :eqz), do: 0x45
    defp do_operation(:i32, :eq), do: 0x46
    defp do_operation(:i32, :ne), do: 0x47
    defp do_operation(:i32, :lt_s), do: 0x48
    defp do_operation(:i32, :lt_u), do: 0x49
    defp do_operation(:i32, :gt_s), do: 0x4A
    defp do_operation(:i32, :gt_u), do: 0x4B
    defp do_operation(:i32, :le_s), do: 0x4C
    defp do_operation(:i32, :le_u), do: 0x4D
    defp do_operation(:i32, :ge_s), do: 0x4E
    defp do_operation(:i32, :ge_u), do: 0x4F

    defp do_operation(:i64, :eqz), do: 0x50
    defp do_operation(:i64, :eq), do: 0x51
    defp do_operation(:i64, :ne), do: 0x52
    defp do_operation(:i64, :lt_s), do: 0x53
    defp do_operation(:i64, :lt_u), do: 0x54
    defp do_operation(:i64, :gt_s), do: 0x55
    defp do_operation(:i64, :gt_u), do: 0x56
    defp do_operation(:i64, :le_s), do: 0x57
    defp do_operation(:i64, :le_u), do: 0x58
    defp do_operation(:i64, :ge_s), do: 0x59
    defp do_operation(:i64, :ge_u), do: 0x5A

    defp do_operation(:f32, :eq), do: 0x5B
    defp do_operation(:f32, :ne), do: 0x5C
    defp do_operation(:f32, :lt), do: 0x5D
    defp do_operation(:f32, :gt), do: 0x5E
    defp do_operation(:f32, :le), do: 0x5F
    defp do_operation(:f32, :ge), do: 0x60

    defp do_operation(:f64, :eq), do: 0x61
    defp do_operation(:f64, :ne), do: 0x62
    defp do_operation(:f64, :lt), do: 0x63
    defp do_operation(:f64, :gt), do: 0x64
    defp do_operation(:f64, :le), do: 0x65
    defp do_operation(:f64, :ge), do: 0x66
  end
end
