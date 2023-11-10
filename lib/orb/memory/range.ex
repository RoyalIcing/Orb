defmodule Orb.Memory.Range do
  import Bitwise

  def from(byte_offset, byte_length) do
    # :binary.encode_unsigned(byte_offset, :little)
    <<byte_offset::unsigned-little-integer-size(32),
      byte_length::unsigned-little-integer-size(32)>>
  end

  def get_byte_offset(
        <<byte_offset::unsigned-little-integer-size(32), _::unsigned-little-integer-size(32)>>
      ) do
    byte_offset
  end

  def get_byte_length(
        <<_::unsigned-little-integer-size(32), byte_length::unsigned-little-integer-size(32)>>
      ) do
    byte_length
  end
end
