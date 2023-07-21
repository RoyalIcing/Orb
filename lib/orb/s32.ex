defmodule Orb.S32 do
  @moduledoc false

  defmodule DSL do
    @moduledoc """
    Signed 32-bit integer operators.
    """

    import Kernel, except: [/: 2, <: 2, >: 2, <=: 2, >=: 2]

    def left / right do
      Orb.I32.div_s(left, right)
    end

    def left >>> right do
      Orb.I32.shr_s(left, right)
    end

    def left < right do
      Orb.I32.lt_s(left, right)
    end

    def left > right do
      Orb.I32.gt_s(left, right)
    end

    def left <= right do
      Orb.I32.le_s(left, right)
    end

    def left >= right do
      Orb.I32.ge_s(left, right)
    end
  end
end
