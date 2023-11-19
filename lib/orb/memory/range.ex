defmodule Orb.Memory.Range do
  require Orb
  require Orb.I64 |> alias
  require Orb.I32 |> alias
  # import Bitwise

  def from(byte_offset, byte_length) when is_integer(byte_offset) and is_integer(byte_length) do
    # :binary.encode_unsigned(byte_offset, :little)
    <<byte_offset::unsigned-little-integer-size(32),
      byte_length::unsigned-little-integer-size(32)>>
  end

  def from(byte_offset = %{type: _}, byte_length = %{type: _}) do
    Orb.snippet do
      byte_length
      |> I64.extend_i32_u()
      |> I64.or(I64.shl(I64.extend_i32_u(byte_offset), i64(32)))
    end
  end

  def get_byte_offset(
        <<byte_offset::unsigned-little-integer-size(32), _::unsigned-little-integer-size(32)>>
      ) do
    byte_offset
  end

  def get_byte_offset(range = %{type: _}) do
    Orb.snippet do
      I64.shr_u(range, i64(32)) |> I32.wrap_i64()
    end
  end

  def get_byte_length(
        <<_::unsigned-little-integer-size(32), byte_length::unsigned-little-integer-size(32)>>
      ) do
    byte_length
  end

  def get_byte_length(range = %{type: _}) do
    Orb.snippet do
      I32.wrap_i64(range)
    end
  end
end
