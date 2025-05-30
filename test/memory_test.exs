defmodule MemoryTest do
  use ExUnit.Case, async: true
  require TestHelper

  test "import/2" do
    defmodule ImportsMemory do
      use Orb

      Memory.import(:env, :memory)
      Memory.pages(1)
    end

    wat = Orb.to_wat(ImportsMemory)

    assert ~S"""
           (module $ImportsMemory
             (import "env" "memory" (memory 1))
           )
           """ = wat
  end

  test "export/1" do
    defmodule ExportsMemory do
      use Orb

      Memory.export(:foo)
      Memory.pages(1)
    end

    assert ~S"""
           (module $ExportsMemory
             (memory (export "foo") 1)
           )
           """ = Orb.to_wat(ExportsMemory)
  end

  test "initial_data!/2" do
    defmodule InitialData do
      use Orb

      Memory.pages(1)

      Memory.initial_data!(0x100, "abc")
      Memory.initial_data!(0x200, "de\n")
      Memory.initial_data!(0x300, ~s"\x01\x02\x03\x04")
      Memory.initial_data!(0x400, ~s"\x7b")
      Memory.initial_data!(0x500, u8: [4, 16, 3], u8: 12)
      Memory.initial_data!(0x600, u32: [4, 123_456, 3])

      defw read_u8(address: I32), I32.U8 do
        Memory.load!(I32.U8, address)
      end

      defw read_i32(address: I32), I32 do
        Memory.load!(I32, address, align: 4)
      end
    end

    wat = Orb.to_wat(InitialData)
    wasm = Orb.to_wasm(InitialData)

    if false do
      path_wat = Path.join(__DIR__, "initial_data.wat")
      path_wasm = Path.join(__DIR__, "initial_data.wasm")
      File.write!(path_wat, wat)
      File.write!(path_wasm, wasm)
    end

    assert ~S"""
           (module $InitialData
             (memory (export "memory") 1)
             (data (i32.const 256) "abc")
             (data (i32.const 512) "de\n")
             (data (i32.const 768) "\01\02\03\04")
             (data (i32.const 1024) "{")
             (data (i32.const 1280) "\04\10\03\0c")
             (data (i32.const 1536) "\04\00\00\00\40\e2\01\00\03\00\00\00")
             (func $read_u8 (export "read_u8") (param $address i32) (result i32)
               (i32.load8_u (local.get $address))
             )
             (func $read_i32 (export "read_i32") (param $address i32) (result i32)
               (i32.load align=4 (local.get $address))
             )
           )
           """ = wat

    for source <- [wat, wasm] do
      assert ?a = TestHelper.wasm_call(source, :read_u8, 0x100)
      assert "abc\0" = TestHelper.wasm_call(source, :read_i32, 0x100) |> i32_to_ascii()

      assert "de\n\0" = TestHelper.wasm_call(source, :read_i32, 0x200) |> i32_to_ascii()

      assert 1 = TestHelper.wasm_call(source, :read_u8, 0x300)
      assert 2 = TestHelper.wasm_call(source, :read_u8, 0x301)
      assert 3 = TestHelper.wasm_call(source, :read_u8, 0x302)
      assert 4 = TestHelper.wasm_call(source, :read_u8, 0x303)

      assert 0x7B = 123 = TestHelper.wasm_call(source, :read_u8, 0x400)

      assert 4 = TestHelper.wasm_call(source, :read_u8, 0x500)
      assert 16 = TestHelper.wasm_call(source, :read_u8, 0x501)
      assert 3 = TestHelper.wasm_call(source, :read_u8, 0x502)

      assert 4 = TestHelper.wasm_call(source, :read_i32, 0x600)
      assert 123_456 = TestHelper.wasm_call(source, :read_i32, 0x604)
      assert 3 = TestHelper.wasm_call(source, :read_i32, 0x608)
      # assert -1 = TestHelper.wasm_call(source, :read_i32, 0x612)
    end
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

  # Note: Stateful memory tests (like swap!/4) that require persistent state between calls
  # are located in memory_stateful_test.exs using WasmexCase for proper state management.

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
