defmodule Orb.Memory.Slice do
  @moduledoc """
  Similar to [Rust’s slice](https://doc.rust-lang.org/1.77.0/std/primitive.slice.html) but across all memory.
  """

  require Orb.I64 |> alias
  require Orb.I32 |> alias

  with @behaviour Orb.CustomType do
    @impl Orb.CustomType
    def wasm_type, do: :i64
  end

  def from(byte_offset, byte_length) when is_integer(byte_offset) and is_integer(byte_length) do
    # :binary.encode_unsigned(byte_offset, :little)

    # <<i64::unsigned-little-integer-size(64)>> =
    #   <<byte_offset::unsigned-little-integer-size(32),
    #     byte_length::unsigned-little-integer-size(32)>>

    import Bitwise
    byte_length <<< 32 ||| byte_offset
  end

  def from(byte_offset = %{push_type: _}, byte_length = %{push_type: _}) do
    I64.extend_i32_u(byte_offset)
    |> I64.or(
      I64.extend_i32_u(byte_length)
      |> I64.shl(32)
    )
  end

  def get_byte_offset(n) when is_integer(n) do
    # <<byte_offset::unsigned-little-integer-size(32), _::unsigned-little-integer-size(32)>> =
    #   <<n::unsigned-little-integer-size(64)>>

    import Bitwise
    n &&& 0xFFFFFFFF
  end

  def get_byte_offset(
        <<byte_offset::unsigned-little-integer-size(32), _::unsigned-little-integer-size(32)>>
      ) do
    byte_offset
  end

  def get_byte_offset(range = %{push_type: _}) do
    I32.wrap_i64(range)
  end

  def get_byte_length(n) when is_integer(n) do
    # <<_::unsigned-little-integer-size(32), byte_length::unsigned-little-integer-size(32)>> =
    #   <<n::unsigned-little-integer-size(64)>>

    # byte_length

    import Bitwise
    n >>> 32
  end

  def get_byte_length(
        <<_::unsigned-little-integer-size(32), byte_length::unsigned-little-integer-size(32)>>
      ) do
    byte_length
  end

  def get_byte_length(range = %{push_type: _}) do
    I64.shr_u(range, 32) |> I32.wrap_i64()
  end

  # defimpl Orb.ToWat do
  #   def to_wat(
  #         %Orb.Memory.Slice{},
  #         indent
  #       ) do
  #     [
  #       indent,
  #     ]
  #   end
  # end
end
