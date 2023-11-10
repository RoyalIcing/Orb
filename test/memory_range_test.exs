defmodule MemoryRangeTest do
  use ExUnit.Case, async: true

  alias Orb.Memory

  test "from/2" do
    assert Memory.Range.from(0, 0) == <<0x00, 0x00, 0, 0, 0, 0, 0, 0>>
    assert Memory.Range.from(1, 0) == <<0x01, 0x00, 0, 0, 0, 0, 0, 0>>
    assert Memory.Range.from(0, 1) == <<0x00, 0x00, 0, 0, 1, 0, 0, 0>>
    assert Memory.Range.from(15, 1) == <<0x0F, 0x00, 0, 0, 1, 0, 0, 0>>
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
    assert Memory.Range.from(256, 0) |> Memory.Range.get_byte_length() == 0
    assert Memory.Range.from(256, 512) |> Memory.Range.get_byte_length() == 512
    assert Memory.Range.from(0xFFFF, 0xEEEE) |> Memory.Range.get_byte_length() == 0xEEEE
  end
end
