defmodule MemoryRangeTest do
  use ExUnit.Case, async: true

  alias Orb.Memory

  test "from/2" do
    assert Memory.Range.from(0, 0) == <<0x00, 0x00, 0, 0, 0, 0, 0, 0>>
    assert Memory.Range.from(1, 0) == <<0x01, 0x00, 0, 0, 0, 0, 0, 0>>
    assert Memory.Range.from(0, 1) == <<0x00, 0x00, 0, 0, 1, 0, 0, 0>>
    assert Memory.Range.from(15, 1) == <<0x0F, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00>>
    assert Memory.Range.from(256, 1) == <<0x00, 0x01, 0, 0, 1, 0, 0, 0>>
    assert Memory.Range.from(512, 1) == <<0x00, 0x02, 0, 0, 1, 0, 0, 0>>
    assert Memory.Range.from(512, 1024) == <<0x00, 0x02, 0, 0, 0, 0x04, 0, 0>>
  end

  test "get_byte_offset/1" do
    assert Memory.Range.from(0, 0) |> Memory.Range.get_byte_offset() == 0
    assert Memory.Range.from(256, 0) |> Memory.Range.get_byte_offset() == 256
    assert Memory.Range.from(256, 512) |> Memory.Range.get_byte_offset() == 256
    assert Memory.Range.from(0xFFFF, 0xEEEE) |> Memory.Range.get_byte_offset() == 0xFFFF
  end

  test "get_byte_length/1" do
    assert Memory.Range.from(0, 0) |> Memory.Range.get_byte_length() == 0
    assert Memory.Range.from(0, 256) |> Memory.Range.get_byte_length() == 256
    assert Memory.Range.from(512, 256) |> Memory.Range.get_byte_length() == 256
    assert Memory.Range.from(0xFFFF, 0xEEEE) |> Memory.Range.get_byte_length() == 0xEEEE
  end

  defmodule MemoryRangeSubject do
    use Orb

    defw test, {I64, I32, I32}, a: I32, b: I32, c: I64 do
      a = 0x0F
      b = 2
      c = Memory.Range.from(a, b)

      assert! c === i64(0x0000000F00000002)
      a = Memory.Range.get_byte_offset(c)
      assert! a === i32(0x0F)
      b = Memory.Range.get_byte_length(c)
      assert! b === i32(2)

      c
      Memory.Range.get_byte_offset(c)
      Memory.Range.get_byte_length(c)
    end
  end

  test "in WebAssembly" do
    {c, a, b} = OrbWasmtime.Wasm.call(MemoryRangeSubject, :test)
    assert c === 0x0000000F00000002
    assert a === 0x0F
    assert b === 2
  end
end
