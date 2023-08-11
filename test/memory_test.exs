defmodule MemoryTest do
  use ExUnit.Case, async: true

  use Orb

  test "load!/2" do
    defmodule Load do
      use Orb

      wasm do
        func load() do
          Memory.load!(I32, 0x100)
          :drop

          memory32_8![0x100].unsigned
          :drop

          Memory.load!(I32.U8, 0x100)
          :drop
        end
      end
    end

    assert to_wat(Load) == """
           (module $Load
             (func $load (export "load")
               (i32.load (i32.const 256))
               drop
               (i32.load8_u (i32.const 256))
               drop
               (i32.load8_u (i32.const 256))
               drop
             )
           )
           """
  end
end
