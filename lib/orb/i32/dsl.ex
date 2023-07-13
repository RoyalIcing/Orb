defmodule Orb.I32.DSL do
  import Kernel, except: [===: 2, !==: 2]

  def left === right do
    Orb.I32.eq(left, right)
  end

  def left !== right do
    Orb.I32.eq(left, right) |> Orb.I32.eqz()
  end
end
