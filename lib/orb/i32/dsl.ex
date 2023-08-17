defmodule Orb.I32.DSL do
  @moduledoc """
  The operators that work consistently signed or unsigned.

  Signed specific: `Orb.S32.DSL`

  Unsigned specific: `Orb.U32.DSL`
  """

  import Kernel, except: [+: 2, -: 2, *: 2, ===: 2, !==: 2, not: 1, or: 2]

  def left + right do
    Orb.Numeric.Add.optimized(Orb.I32, left, right)
  end

  def left - right do
    Orb.Numeric.Subtract.optimized(Orb.I32, left, right)
  end

  def left * right do
    Orb.Numeric.Multiply.optimized(Orb.I32, left, right)
    # Orb.I32.mul(left, right)
  end

  def _left == _right do
    raise "== is not supported in Orb. Use === instead."
  end

  def left === right do
    Orb.I32.eq(left, right)
  end

  def _left != _right do
    raise "!= is not supported in Orb. Use !== instead."
  end

  def left !== right do
    Orb.Numeric.NotEqual.optimized(Orb.I32, left, right)
  end

  def left ||| right do
    Orb.I32.or(left, right)
  end

  def left &&& right do
    Orb.I32.band(left, right)
  end

  def left <<< right do
    Orb.I32.shl(left, right)
  end

  def not value do
    Orb.I32.eqz(value)
  end

  def left or right do
    Orb.I32.or(left, right)
  end
end
