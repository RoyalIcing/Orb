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
        Kernel.+(left, right)

      Float ->
        Kernel.+(left, right)

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
        Orb.Instruction.new(type, :eq, [left, right])
    end
  end

  def left !== right do
    # Orb.Numeric.NotEqual.optimized(Orb.I32, left, right)
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_type(type) ->
        Orb.Instruction.new(type, :ne, [left, right])
    end
  end

  def left < right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :lt_s, [left, right])

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.new(type, :lt, [left, right])
    end
  end

  def left > right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :gt_s, [left, right])

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.new(type, :gt, [left, right])
    end
  end

  def left <= right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :le_s, [left, right])

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.new(type, :le, [left, right])
    end
  end

  def left >= right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :ge_s, [left, right])

      type when Ops.is_primitive_float_type(type) ->
        Orb.Instruction.new(type, :ge, [left, right])
    end
  end

  def left ||| right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :or, [left, right])
    end
  end

  def left &&& right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :and, [left, right])
    end
  end

  def left <<< right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :shl, [left, right])
    end
  end

  def not value do
    case Ops.typeof(value, :primitive) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :eqz, [value])
    end
  end

  def left or right do
    case Ops.extract_common_type(left, right) do
      type when Ops.is_primitive_integer_type(type) ->
        Orb.Instruction.new(type, :or, [left, right])
    end
  end

  # def left and right do
  #   Orb.I32.band(left, right)
  # end
end
