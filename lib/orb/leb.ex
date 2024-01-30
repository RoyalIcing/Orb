defmodule Orb.Leb do
  def uleb128(0), do: [0]
  def uleb128(n), do: uleb128(n, [])

  defp uleb128(0, bytes), do: bytes |> Enum.reverse()

  defp uleb128(value, bytes) do
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

    uleb128(value, [byte | bytes])
  end
end
