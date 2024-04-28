defmodule MemoryTest do
  use ExUnit.Case, async: true
  require TestHelper

  test "initial_data!/2" do
    defmodule InitialData do
      use Orb

      Memory.pages(1)

      Memory.initial_data!(0x100, "abc")
      Memory.initial_data!(0x200, "def")
      Memory.initial_data!(0x300, ~S"\01\02\03\04")
      Memory.initial_data!(0x400, ~S"\7b")
      Memory.initial_data!(0x500, u8: [4, 16, 3], u8: 12)
      Memory.initial_data!(0x600, u32: [4, 123_456, 3])

      defw read_u8(address: I32), I32.U8 do
        Memory.load!(I32.U8, address)
      end

      defw read_i32(address: I32), I32 do
        Memory.load!(I32, address)
      end
    end

    assert ~S"""
           (module $InitialData
             (memory (export "memory") 1)
             (data (i32.const 256) "abc")
             (data (i32.const 512) "def")
             (data (i32.const 768) "\01\02\03\04")
             (data (i32.const 1024) "\7b")
             (data (i32.const 1280) "\04\10\03\0c")
             (data (i32.const 1536) "\04\00\00\00\40\e2\01\00\03\00\00\00")
             (func $read_u8 (export "read_u8") (param $address i32) (result i32)
               (i32.load8_u (local.get $address))
             )
             (func $read_i32 (export "read_i32") (param $address i32) (result i32)
               (i32.load (local.get $address))
             )
           )
           """ = Orb.to_wat(InitialData)

    alias OrbWasmtime.Instance

    inst = Instance.run(InitialData)
    assert ?a = Instance.call(inst, :read_u8, 0x100)
    assert "abc\0" = Instance.call(inst, :read_i32, 0x100) |> i32_to_ascii()

    assert "def\0" = Instance.call(inst, :read_i32, 0x200) |> i32_to_ascii()

    assert 1 = Instance.call(inst, :read_u8, 0x300)
    assert 2 = Instance.call(inst, :read_u8, 0x301)
    assert 3 = Instance.call(inst, :read_u8, 0x302)
    assert 4 = Instance.call(inst, :read_u8, 0x303)

    assert 0x7B = 123 = Instance.call(inst, :read_u8, 0x400)

    assert 4 = Instance.call(inst, :read_u8, 0x500)
    assert 16 = Instance.call(inst, :read_u8, 0x501)
    assert 3 = Instance.call(inst, :read_u8, 0x502)

    assert 4 = Instance.call(inst, :read_i32, 0x600)
    assert 123_456 = Instance.call(inst, :read_i32, 0x604)
    assert 3 = Instance.call(inst, :read_i32, 0x608)
    # assert -1 = Instance.call(inst, :read_i32, 0x612)
  end

  defp i32_to_ascii(i32) when is_integer(i32), do: <<i32::little-size(32)>>

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
