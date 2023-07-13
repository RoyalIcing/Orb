defmodule Orb.U32 do
  def apply_to_ast(nodes) do
    nodes
  end

  defmodule DSL do
    @moduledoc """
    Unsigned 32-bit integer operators.
    """

    import Kernel, except: [/: 2, ===: 2, !==: 2, <=: 2, >=: 2]

    def left / right do
      Orb.I32.div_u(left, right)
    end

    def left >>> right do
      Orb.I32.shr_u(left, right)
    end

    def left < right do
      Orb.I32.lt_u(left, right)
    end

    def left > right do
      Orb.I32.gt_u(left, right)
    end

    def left <= right do
      Orb.I32.le_u(left, right)
    end

    def left >= right do
      Orb.I32.ge_u(left, right)
    end
  end
end
