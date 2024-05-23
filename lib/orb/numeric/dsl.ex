defmodule Orb.Numeric.DSL do
  @moduledoc """
  Operators that work with all number types.
  """

  import Kernel, except: [+: 2, -: 2, *: 2, ===: 2, !==: 2, not: 1, or: 2]
  require alias Orb.Ops

  def left + right do
    case Ops.extract_common_type(left, right) do
      Integer ->
        Kernel.+(left, right)

      Float ->
        Kernel.+(left, right)

      type when Ops.is_primitive_integer_type(type) ->
        Orb.Numeric.Add.optimized(type, left, right)

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.new(type, :add, [left, right])
    end
  end

  def left - right do
    case Ops.extract_common_type(left, right) do
      Integer ->
        Kernel.-(left, right)

      Float ->
        Kernel.-(left, right)

      type when Ops.is_primitive_integer_type(type) ->
        Orb.Numeric.Subtract.optimized(type, left, right)

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.new(type, :sub, [left, right])
    end
  end

  def left * right do
    case Ops.extract_common_type(left, right) do
      type when type in [Integer, Float] ->
        Kernel.*(left, right)

      type when Ops.is_primitive_integer_type(type) ->
        Orb.Numeric.Multiply.optimized(type, left, right)

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.new(type, :mul, [left, right])
    end
  end

  def left / right do
    case Ops.extract_common_type(left, right) do
      Elixir.Integer ->
        Kernel.div(left, right)

      Elixir.Float ->
        Kernel./(left, right)

      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :div_s, [left, right])

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.new(type, :div, [left, right])

      _ ->
        raise Orb.TypeCheckError,
          expected_type: Ops.typeof(left),
          received_type: Ops.typeof(right),
          instruction_identifier: "div"
    end
  end

  def _left == _right do
    raise "== is not supported in Orb. Use === instead."
  end

  def _left != _right do
    raise "!= is not supported in Orb. Use !== instead."
  end

  def left === right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_type(type) ->
        Orb.Instruction.Relative.new(type, :eq, left, right)
    end
  end

  def left !== right do
    # Orb.Numeric.NotEqual.optimized(Orb.I32, left, right)
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_type(type) ->
        Orb.Instruction.Relative.new(type, :ne, left, right)
    end
  end

  def left < right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.Relative.new(type, :lt_s, left, right)

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.Relative.new(type, :lt, left, right)
    end
  end

  def left > right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.Relative.new(type, :gt_s, left, right)

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.Relative.new(type, :gt, left, right)
    end
  end

  def left <= right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.Relative.new(type, :le_s, left, right)

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.Relative.new(type, :le, left, right)
    end
  end

  def left >= right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.Relative.new(type, :ge_s, left, right)

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.Relative.new(type, :ge, left, right)
    end
  end

  @doc """
  Bitwise OR operation for i32 or i64 integers.

  ## Examples

      use Orb

      defw bitwise_or_example(a: I32, b: I32), I32 do
        a ||| b
      end

  """
  def left ||| right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :or, [left, right])

      type when Ops.is_primitive_float_type(type) ->
        raise ArgumentError, "Cannot ||| two expressions of type #{type}."
    end
  end

  @doc """
  Bitwise AND operation for i32 or i64 integers.

  ## Examples

      use Orb

      defw bitwise_and_example(a: I32, b: I32), I32 do
        a &&& b
      end

  """
  def left &&& right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :and, [left, right])

      type when Ops.is_primitive_float_type(type) ->
        raise ArgumentError, "Cannot &&& two expressions of type #{type}."
    end
  end

  @doc """
  Left shift operation for i32 or i64 integers.

  ## Examples

      use Orb

      defw left_shift_by_4(a: I32), I32 do
        a <<< 4
      end

  """
  def left <<< right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :shl, [left, right])

      type when Ops.is_primitive_float_type(type) ->
        raise ArgumentError, "Cannot <<< two expressions of type #{type}."
    end
  end

  @doc """
  Logical NOT operation for i32 or i64 integers. Returns i32.

  Zero is considered false, all other numbers are considered true.

  It does not support short-circuiting.

  ## Examples

      use Orb

      defw not_example(a: I32), I32 do
        not a
      end

  """
  def not value do
    case Ops.typeof(value, :primitive) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :eqz, [value])

      type when Ops.is_primitive_float_type(type) ->
        raise ArgumentError, "Cannot NOT two expressions of type #{type}."
    end
  end

  @doc """
  Logical OR operation for i32 or i64 integers. Returns i32.

  Zero is considered false, all other numbers are considered true.

  It does not support short-circuiting.

  ## Examples

      use Orb

      defw or_example(a: I32, b: I32), I32 do
        a or b
      end

  """
  def left or right do
    case Ops.extract_common_type(left, right) do
      :i32 ->
        Orb.Instruction.new(:i32, :or, [left, right])

      type when Ops.is_primitive_float_type(type) ->
        raise ArgumentError, "Cannot OR two expressions of type #{type}."
    end
  end

  @doc """
  Logical AND operation for i32 or i64 integers. Returns i32.

  Zero is considered false, all other numbers are considered true.

  It does not support short-circuiting.

  ## Examples

      use Orb

      defw and_example(a: I32, b: I32), I32 do
        a and b
      end

  """
  def left and right do
    case Ops.extract_common_type(left, right) do
      :i32 ->
        Orb.Instruction.new(:i32, :and, [left, right])

      type when Ops.is_primitive_float_type(type) ->
        raise ArgumentError, "Cannot AND two expressions of type #{type}."
    end
  end
end
