defmodule LebTest do
  use ExUnit.Case, async: true

  import Orb.Leb

  test "unsigned" do
    assert [0] = uleb128(0)
    assert [1] = uleb128(1)
    assert [2] = uleb128(2)
    assert [64] = uleb128(64)
    assert [0x80, 1] = uleb128(0x80)
    assert [0x81, 1] = uleb128(0x81)
    assert [0x90, 1] = uleb128(0x90)
    assert [0xFF, 1] = uleb128(0xFF)
    assert [0x80, 2] = uleb128(0x100)
    assert [0x81, 2] = uleb128(0x101)
    assert [0xFF, 0x7F] = uleb128(0x3FFF)
    assert [0x80, 0x80, 1] = uleb128(0x4000)
    assert [0xFF, 0xFF, 1] = uleb128(0x7FFF)
    assert [0xFF, 0xFF, 3] = uleb128(0xFFFF)
  end
end
