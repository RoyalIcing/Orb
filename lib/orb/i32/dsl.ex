defmodule Orb.I32.DSL do
  @moduledoc """
  The operators agonistic shared across both signed and unsigned.
  """

  import Kernel, except: [===: 2, !==: 2]

  def left === right do
    Orb.I32.eq(left, right)
  end

  def left !== right do
    Orb.I32.eq(left, right) |> Orb.I32.eqz()
  end
end
