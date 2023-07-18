defmodule Orb.U32 do
  @moduledoc false

  defmodule DSL do
    @moduledoc """
    Unsigned 32-bit integer operators.

    Some operators like division have two variations in WebAssembly: signed and unsigned. By default math perform signed operations, but if you want unsigned math you can pass `U32` to `Orb.wasm/2` like so: `wasm U32 do`.
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
