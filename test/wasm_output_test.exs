defmodule WasmOutputTest do
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
             <<0x0A, 0x06, 0x01, 0x04, 0x00, 0x41, 42, 0x0B>> =
             Orb.to_wasm(Basic)
  end

  test "func params" do
    defmodule Basic do
      use Orb

      defw multiply(a: I32, b: I32), I32 do
        a * b
      end
    end

    ~S"""
    (module $Basic
      (func $multiply (export "multiply") (param $a i32) (param $b i32) (result i32)
        (i32.mul (local.get $a) (local.get $b))
      )
    )
    """ = Orb.to_wat(Basic)

    assert <<"\0asm", 0x01000000::32>> <>
             <<0x01, 0x07, 0x01>> <>
             <<0x60, 0x02, 0x7F, 0x7F, 0x01, 0x7F>> <>
             <<0x03, 0x02, 0x01, 0x00>> <>
             <<0x07, 0x0C, 0x01, 0x08, "multiply", 0x00, 0x00>> <>
             <<0x0A, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6C, 0x0B>> =
             Orb.to_wasm(Basic)
  end
end
