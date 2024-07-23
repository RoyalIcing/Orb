defmodule LebTest do
  use ExUnit.Case, async: true

  import Orb.Leb

  test "unsigned" do
    assert [0] = leb128_u(0)
    assert [1] = leb128_u(1)
    assert [2] = leb128_u(2)
    assert [64] = leb128_u(64)
    assert [0x80, 1] = leb128_u(0x80)
    assert [0x81, 1] = leb128_u(0x81)
    assert [0x90, 1] = leb128_u(0x90)
    assert [0xFF, 1] = leb128_u(0xFF)
    assert [0x80, 2] = leb128_u(0x100)
    assert [0x81, 2] = leb128_u(0x101)
    assert [0xFF, 0x7F] = leb128_u(0x3FFF)
    assert [0x80, 0x80, 1] = leb128_u(0x4000)
    assert [0xFF, 0xFF, 1] = leb128_u(0x7FFF)
    assert [0xFF, 0xFF, 3] = leb128_u(0xFFFF)
  end

  test "signed" do
    assert [0] = leb128_s(0)
    assert [0x7F] = leb128_s(-1)
    assert [2] = leb128_s(2)
    assert [0x5F] = leb128_s(-33)
    assert [0xA8, 0x7F] = leb128_s(-88)
    assert [0xC0, 0xBB, 0x78] = leb128_s(-123_456)
    assert [0xE5, 0x8E, 0x26] = leb128_s(624_485)
    assert [0x82, 0xDC, 0xA4, 0x91, 0x7E] = leb128_s(-500_617_726)

    assert [0x81, 0xDC, 0x90, 0xC4, 0xBF, 0xFA, 0xCD, 0xF6, 0x33] =
             leb128_s(3_741_708_248_961_789_441)
  end
end
