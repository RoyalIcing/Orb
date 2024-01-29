defmodule WasmOutputTest do
  use ExUnit.Case, async: true

  import Orb, only: [to_wasm: 1]

  test "basic module" do
    import Orb.DSL

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
             <<0x0A, 0x06, 0x01, 0x04, 0x00, 0x41, 0x2A, 0x0B>> =
             to_wasm(Basic)
  end
end
