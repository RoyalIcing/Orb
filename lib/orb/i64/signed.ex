defmodule Orb.I64.Signed.DSL do
  @moduledoc """
  Signed 32-bit integer operators.
  """

  import Kernel, except: [/: 2, <: 2, >: 2, <=: 2, >=: 2]

  def left / right do
    Orb.I64.div_s(left, right)
  end

  def left >>> right do
    Orb.I64.shr_s(left, right)
  end

  def left < right do
    Orb.I64.lt_s(left, right)
  end

  def left > right do
    Orb.I64.gt_s(left, right)
  end

  def left <= right do
    Orb.I64.le_s(left, right)
  end

  def left >= right do
    Orb.I64.ge_s(left, right)
  end
end
