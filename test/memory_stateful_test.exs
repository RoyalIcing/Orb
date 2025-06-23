defmodule MemoryStatefulTest do
  use WasmexCase, async: true

  # Helper function to unwrap Wasmex.call_function results
  defp call_and_unwrap(context, function, args \\ []) do
    {:ok, result} = context.call_function.(function, args)

    case result do
      [] -> nil
      [single] -> single
      multiple when is_list(multiple) -> List.to_tuple(multiple)
    end
  end

  describe "swap!/4" do
    defmodule Swap do
      use Orb

      Memory.pages(1)
      Memory.initial_data!(16, u32: [123_456, 456_789])

      defw read(), {I32, I32} do
        Memory.load!(I32, 16)
        Memory.load!(I32, 20)
      end

      defw swap() do
        Memory.swap!(I32, 16, 20, align: 4)
      end
    end

    @tag wat: Orb.to_wat(Swap)
    test "swap function modifies memory state", context do
      # Initial read should return the original values
      assert {123_456, 456_789} = call_and_unwrap(context, "read")

      # Swap the values in memory
      call_and_unwrap(context, "swap")

      # Read again should return swapped values
      assert {456_789, 123_456} = call_and_unwrap(context, "read")
    end
  end

  describe "stateful memory operations" do
    defmodule Counter do
      use Orb

      Memory.pages(1)
      Memory.initial_data!(0, u32: 0)

      defw get_count(), I32 do
        Memory.load!(I32, 0)
      end

      defw increment() do
        Memory.store!(I32, 0, Memory.load!(I32, 0) + 1)
      end

      defw reset() do
        Memory.store!(I32, 0, 0)
      end
    end

    @tag wat: Orb.to_wat(Counter)
    test "counter maintains state between calls", context do
      # Initial count should be 0
      assert 0 = call_and_unwrap(context, "get_count")

      # Increment and check
      call_and_unwrap(context, "increment")
      assert 1 = call_and_unwrap(context, "get_count")

      # Increment again
      call_and_unwrap(context, "increment")
      assert 2 = call_and_unwrap(context, "get_count")

      # Reset and check
      call_and_unwrap(context, "reset")
      assert 0 = call_and_unwrap(context, "get_count")
    end
  end

  describe "copy!/3" do
    defmodule StringCopier do
      use Orb

      # memory Const, pages: 1 do
      #   {100, "abc"}
      #   {200, "xyz"}
      # end

      Memory.pages(1)
      # Store "abc" at offset 100
      Memory.initial_data!(100, "abc")
      # Store "xyz" at offset 200
      Memory.initial_data!(200, "xyz")

      defw copy_string(choose: I32) do
        if choose === 1 do
          # Copy "abc" (3 bytes) from offset 100 to output buffer at offset 300
          Memory.copy!(300, 100, 3)
        else
          # Copy "xyz" (3 bytes) from offset 200 to output buffer at offset 300
          Memory.copy!(300, 200, 3)
        end
      end

      defw read_output_string(), {I32, I32, I32} do
        {Memory.load!(I32.U8, 300), Memory.load!(I32.U8, 301), Memory.load!(I32.U8, 302)}
      end
    end

    @tag wat: Orb.to_wat(StringCopier)
    test "wat: copies different strings based on condition", context do
      call_and_unwrap(context, "copy_string", [1])
      assert {?a, ?b, ?c} = call_and_unwrap(context, "read_output_string")

      call_and_unwrap(context, "copy_string", [0])
      assert {?x, ?y, ?z} = call_and_unwrap(context, "read_output_string")

      call_and_unwrap(context, "copy_string", [1])
      assert {?a, ?b, ?c} = call_and_unwrap(context, "read_output_string")
    end

    @tag wasm: Orb.to_wasm(StringCopier)
    test "wasm: copies different strings based on condition", context do
      call_and_unwrap(context, "copy_string", [1])
      assert {?a, ?b, ?c} = call_and_unwrap(context, "read_output_string")

      call_and_unwrap(context, "copy_string", [0])
      assert {?x, ?y, ?z} = call_and_unwrap(context, "read_output_string")

      call_and_unwrap(context, "copy_string", [1])
      assert {?a, ?b, ?c} = call_and_unwrap(context, "read_output_string")
    end
  end

  describe "fill!/3 and copy!/3 combined" do
    defmodule FillAndCopy do
      use Orb

      Memory.pages(1)
      Memory.initial_data!(100, "hello")

      defw setup_buffer() do
        # Fill a buffer with 0x42 at offset 200 (64 bytes)
        Memory.fill!(200, 0x42, 64)
        # Fill another buffer with 0xFF at offset 300 (32 bytes)
        Memory.fill!(300, 0xFF, 32)
      end

      defw copy_data() do
        # Copy "hello" from offset 100 to the 0x42-filled buffer at offset 200
        Memory.copy!(200, 100, 5)
        # Copy first 3 bytes from the hello buffer to the 0xFF buffer
        Memory.copy!(300, 100, 3)
      end

      defw read_buffers(), {I32, I32, I32, I32, I32, I32} do
        {
          # 'h' after copy
          Memory.load!(I32.U8, 200),
          # should be 0x42 (from fill)
          Memory.load!(I32.U8, 205),
          # should be 0x42 (from fill)
          Memory.load!(I32.U8, 210),
          # 'h' after copy
          Memory.load!(I32.U8, 300),
          # should be 0xFF (from fill)
          Memory.load!(I32.U8, 303),
          # should be 0xFF (from fill)
          Memory.load!(I32.U8, 310)
        }
      end
    end

    @tag wasm: Orb.to_wasm(FillAndCopy)
    test "fill and copy operations work together", context do
      call_and_unwrap(context, "setup_buffer")
      {0x42, 0x42, 0x42, 0xFF, 0xFF, 0xFF} = call_and_unwrap(context, "read_buffers")

      # Copy data into the filled buffers
      call_and_unwrap(context, "copy_data")

      # After copy, some positions should have copied data
      {b1, b2, b3, b4, b5, b6} = call_and_unwrap(context, "read_buffers")
      # 'h' copied from "hello"
      assert b1 == ?h
      # still 0x42 (beyond copied data)
      assert b2 == 0x42
      # still 0x42 (beyond copied data)
      assert b3 == 0x42
      # 'h' copied from "hello"
      assert b4 == ?h
      # still 0xFF (beyond copied data)
      assert b5 == 0xFF
      # still 0xFF (beyond copied data)
      assert b6 == 0xFF
    end
  end

  describe "simple WASM tests" do
    defmodule SimpleWasmTest do
      use Orb

      Memory.pages(1)
      Memory.initial_data!(100, "hello")

      defw read_char(), I32 do
        Memory.load!(I32.U8, 100)
      end

      defw store_and_read(), I32 do
        Memory.store!(I32.U8, 200, ?x)
        Memory.load!(I32.U8, 200)
      end
    end

    @tag wasm: Orb.to_wasm(SimpleWasmTest)
    test "basic memory operations work with WASM binary", context do
      assert ?h = call_and_unwrap(context, "read_char")
      assert ?x = call_and_unwrap(context, "store_and_read")
    end

    # Note: memory.copy (bulk memory operations) may require specific WASM runtime features
    # that aren't available in all environments. The WAT format test still works.
  end
end

defmodule MemoryWatGenerationTest do
  use ExUnit.Case, async: true

  describe "WAT generation" do
    defmodule Swap do
      use Orb

      Memory.pages(1)
      Memory.initial_data!(16, u32: [123_456, 456_789])

      defw read(), {I32, I32} do
        Memory.load!(I32, 16)
        Memory.load!(I32, 20)
      end

      defw swap() do
        Memory.swap!(I32, 16, 20, align: 4)
      end
    end

    test "swap!/4 generates correct WAT" do
      wat = Orb.to_wat(Swap)

      assert ~S"""
             (module $Swap
               (memory (export "memory") 1)
               (data (i32.const 16) "\40\e2\01\00\55\f8\06\00")
               (func $read (export "read") (result i32 i32)
                 (i32.load (i32.const 16))
                 (i32.load (i32.const 20))
               )
               (func $swap (export "swap")
                 (i32.const 20)
                 (i32.load align=4 (i32.const 16))
                 (i32.const 16)
                 (i32.load align=4 (i32.const 20))
                 (i32.store align=4 (;i32;) (;i32;))
                 (i32.store align=4 (;i32;) (;i32;))
               )
             )
             """ = wat
    end

    test "swap!/4 compiles to wasm" do
      wasm = Orb.to_wasm(Swap)
    end
  end
end
