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

  alias __MODULE__, as: Self

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(
          %Self{
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
end
