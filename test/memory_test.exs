defmodule MemoryTest do
  use ExUnit.Case, async: true

  test "load!/2" do
    defmodule Load do
      use Orb

      defw load() do
        Memory.load!(I32, 0x100)
        :drop

        Memory.load!(I32.U8, 0x100)
        :drop
      end
    end

    assert Orb.to_wat(Load) == """
           (module $Load
             (func $load (export "load")
               (i32.load (i32.const 256))
               drop
               (i32.load8_u (i32.const 256))
               drop
             )
           )
           """
  end

  test "store!/3" do
    defmodule Store do
      use Orb

      defw store() do
        Memory.store!(I32, 0x100, 42)
        :drop

        Memory.store!(I32.U8, 0x100, 42)
        :drop
      end
    end

    assert Orb.to_wat(Store) == """
           (module $Store
             (func $store (export "store")
               (i32.store (i32.const 256) (i32.const 42))
               drop
               (i32.store8 (i32.const 256) (i32.const 42))
               drop
             )
           )
           """
  end

  test "grow!/1" do
    defmodule Grow do
      use Orb

      defw grow() do
        Memory.grow!(1)
        :drop

        Memory.grow!(0)
        :drop

        Memory.grow!(2)
        :drop
      end
    end

    assert Orb.to_wat(Grow) == """
           (module $Grow
             (func $grow (export "grow")
               (memory.grow (i32.const 1))
               drop
               (memory.grow (i32.const 0))
               drop
               (memory.grow (i32.const 2))
               drop
             )
           )
           """
  end
end
