defmodule Orb.Leb do
  @moduledoc false

  def leb128_u(0), do: [0]
  def leb128_u(n), do: leb128_u(n, [])

  defp leb128_u(0, bytes), do: bytes |> Enum.reverse()

  defp leb128_u(value, bytes) do
    import Bitwise

    byte = value &&& 0x7F
    value = value >>> 7

    byte =
      case value do
        0 ->
          byte

        _ ->
          byte ||| 0x80
      end

    leb128_u(value, [byte | bytes])
  end

  def leb128_s(0), do: [0]
  def leb128_s(n), do: leb128_s(n, [])

  defp leb128_s(value, bytes) do
    import Bitwise

    byte = value &&& 0x7F
    value = value >>> 7

    cond do
      (value === 0 and (byte &&& 0x40) === 0) or (value === -1 and (byte &&& 0x40) !== 0) ->
        [byte | bytes] |> Enum.reverse()

      true ->
        byte = byte ||| 0x80
        leb128_s(value, [byte | bytes])
    end
  end
end
