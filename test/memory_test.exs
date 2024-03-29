defmodule MemoryTest do
  use ExUnit.Case, async: true

  test "load!/2" do
    defmodule Load do
      use Orb

      defw load() do
        Memory.load!(I32, 0x100)
        |> Orb.Stack.drop()

        Memory.load!(I32.U8, 0x100)
        |> Orb.Stack.drop()
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
        Memory.store!(I32.U8, 0x100, 42)
      end
    end

    assert Orb.to_wat(Store) == """
           (module $Store
             (func $store (export "store")
               (i32.store (i32.const 256) (i32.const 42))
               (i32.store8 (i32.const 256) (i32.const 42))
             )
           )
           """
  end

  test "size/1 and grow!/1" do
    defmodule Grow do
      use Orb

      defw grow(), a: I32 do
        a = Memory.size()

        a = Memory.grow!(1)
        _ = Memory.grow!(0)
        _ = Memory.grow!(2)
      end
    end

    assert Orb.to_wat(Grow) == """
           (module $Grow
             (func $grow (export "grow")
               (local $a i32)
               (memory.size)
               (local.set $a)
               (memory.grow (i32.const 1))
               (local.set $a)
               (memory.grow (i32.const 0))
               drop
               (memory.grow (i32.const 2))
               drop
             )
           )
           """
  end
end
