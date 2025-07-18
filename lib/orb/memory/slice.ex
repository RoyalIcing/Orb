defmodule Orb.Memory.Slice do
  @moduledoc """
  Similar to [Rust’s slice](https://doc.rust-lang.org/1.77.0/std/primitive.slice.html) but across all memory.
  """

  alias require Orb.I64
  alias require Orb.I32

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

  def from(byte_offset, byte_length) do
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

  def get_byte_offset(slice = %{push_type: _}) do
    I32.wrap_i64(slice)
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

  def get_byte_length(slice = %{push_type: _}) do
    I64.shr_u(slice, 32) |> I32.wrap_i64()
  end

  def drop_first_byte(slice = %{push_type: _}) do
    require Orb
    require Orb.Instruction

    Orb.Instruction.sequence do
      if get_byte_length(slice) === 0 do
        slice
      else
        from(get_byte_offset(slice) + 1, get_byte_length(slice) - 1)
      end
    end
  end

  with @behaviour b = Orb.Iterator do
    @impl b
    def valid?(var), do: get_byte_length(var)

    @impl b
    def value_type(), do: Orb.I32

    @impl b
    def value(var), do: Orb.Memory.load!(I32.U8, get_byte_offset(var))

    @impl b
    def next(var), do: drop_first_byte(var)
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
