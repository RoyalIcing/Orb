defmodule WasmOutputTest do
  alias OrbWasmtime.Wasm
  use ExUnit.Case, async: true

  test "basic module" do
    defmodule Basic do
      use Orb

      defw answer(), I32 do
        42
      end
    end

    assert <<"\0asm", 0x01000000::32>> <>
             <<0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7F>> <>
             <<0x03, 0x02, 0x01, 0x00>> <>
             <<0x07, 0x0A, 0x01, 0x06, "answer", 0x00, 0x00>> <>
             <<0x0A, 0x06, 0x01, 0x04, 0x00, <<0x41, 42>>, 0x0B>> =
             Orb.to_wasm(Basic)
  end

  test "i23 operations and func params" do
    defmodule MathI32 do
      use Orb

      defw math(a: I32, b: I32), I32, denominator: I32 do
        a * b / (4 + a - b)
      end
    end

    assert ~S"""
           (module $MathI32
             (func $math (export "math") (param $a i32) (param $b i32) (result i32)
               (local $denominator i32)
               (i32.div_s (i32.mul (local.get $a) (local.get $b)) (i32.sub (i32.add (i32.const 4) (local.get $a)) (local.get $b)))
             )
           )
           """ === Orb.to_wat(MathI32)

    assert <<"\0asm", 0x01000000::32>> <>
             <<0x01, 0x07, 0x01>> <>
             <<0x60, 0x02, 0x7F, 0x7F, 0x01, 0x7F>> <>
             <<0x03, 0x02, 0x01, 0x00>> <>
             <<0x07, 0x08, 0x01, 0x04, "math", 0x00, 0x00>> <>
             <<0x0A, 0x12, 0x01, 0x10, 0x00, <<0x20, 0x00>>, <<0x20, 0x01>>, 0x6C, <<0x41, 0x04>>,
               <<0x20, 0x00>>, 0x6A, <<0x20, 0x01>>, 0x6B, 0x6D,
               0x0B>> =
             Orb.to_wasm(MathI32)

    assert (11 * 7) |> div(4 + 11 - 7) === 9
    assert Orb.to_wat(MathI32) |> Wasm.call(:math, 11, 7) === 9
    assert Orb.to_wasm(MathI32) |> Wasm.call(:math, 11, 7) === 9
  end
end
