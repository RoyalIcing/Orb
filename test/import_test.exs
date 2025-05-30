defmodule ImportTest do
  use ExUnit.Case, async: true
  require TestHelper

  test "Orb.Import.register/1" do
    defmodule ImportsExample do
      use Orb

      defmodule Echo do
        use Orb.Import, name: :echo

        defw(int32(a: I32), I32)
        defw(int64(a: I64), I64)
      end

      defmodule Log do
        use Orb.Import, name: :log

        defw(int32(a: I32))
        defw(int64(a: I64))
      end

      defmodule Time do
        use Orb.Import, name: :time

        defw(unix_time(), I64)
      end

      # TODO?:
      # Echo.import()
      # Log.import()
      # Time.import()

      Orb.Import.register(Echo)
      Orb.Import.register(Log)
      Orb.Import.register(Time)

      defw test() do
        Echo.int32(42) |> Orb.Stack.drop()
        Echo.int64(42) |> Orb.Stack.drop()
      end
    end

    wat = Orb.to_wat(ImportsExample)
    wasm = Orb.to_wasm(ImportsExample)

    # Test WAT output
    assert """
           (module $ImportsExample
             (import "echo" "int32" (func $ImportTest.ImportsExample.Echo.int32 (param $a i32) (result i32)))
             (import "echo" "int64" (func $ImportTest.ImportsExample.Echo.int64 (param $a i64) (result i64)))
             (import "log" "int32" (func $ImportTest.ImportsExample.Log.int32 (param $a i32)))
             (import "log" "int64" (func $ImportTest.ImportsExample.Log.int64 (param $a i64)))
             (import "time" "unix_time" (func $ImportTest.ImportsExample.Time.unix_time (result i64)))
             (func $test (export "test")
               (call $ImportTest.ImportsExample.Echo.int32 (i32.const 42))
               drop
               (call $ImportTest.ImportsExample.Echo.int64 (i64.const 42))
               drop
             )
           )
           """ = wat

    # Test WASM binary format contains WASM magic number and import section
    assert <<"\0asm", 0x01000000::32, _rest::binary>> = wasm

    # Test that WASM contains import section (section ID 0x02)
    # This is a basic test to ensure imports are included in binary
    assert String.contains?(wasm, "echo")
    assert String.contains?(wasm, "int32")
    assert String.contains?(wasm, "log")
    assert String.contains?(wasm, "time")
    assert String.contains?(wasm, "unix_time")
  end
end
