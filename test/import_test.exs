defmodule ImportTest do
  use ExUnit.Case, async: true

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
           """ = Orb.to_wat(ImportsExample)
  end

  defmodule ImportsGlobal do
    use Orb

    Orb.Import.register_memory(:env, :memory, 1)
  end

  test "importing memory should work" do

    assert """
           (module $ImportsGlobal
             (import "env" "memory" (memory 1))
           )
           """ = Orb.to_wat(ImportsGlobal)
  end
end
