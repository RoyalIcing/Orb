defmodule Orb.Memory.Range do
  require Orb.I64 |> alias
  require Orb.I32 |> alias
  # import Bitwise

  def from(byte_offset, byte_length) when is_integer(byte_offset) and is_integer(byte_length) do
    # :binary.encode_unsigned(byte_offset, :little)
    <<byte_offset::unsigned-little-integer-size(32),
      byte_length::unsigned-little-integer-size(32)>>
  end

  def from(byte_offset = %{push_type: _}, byte_length = %{push_type: _}) do
    byte_length
    |> I64.extend_i32_u()
    |> I64.or(
      I64.extend_i32_u(byte_offset)
      |> I64.shl(32)
    )
  end

  def get_byte_offset(
        <<byte_offset::unsigned-little-integer-size(32), _::unsigned-little-integer-size(32)>>
      ) do
    byte_offset
  end

  def get_byte_offset(range = %{push_type: _}) do
    I64.shr_u(range, 32) |> I32.wrap_i64()
  end

  def get_byte_length(
        <<_::unsigned-little-integer-size(32), byte_length::unsigned-little-integer-size(32)>>
      ) do
    byte_length
  end

  def get_byte_length(range = %{push_type: _}) do
    I32.wrap_i64(range)
  end
end
