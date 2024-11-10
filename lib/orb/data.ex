defmodule Orb.Data do
  @moduledoc false

  defstruct [:offset, :value]

  defimpl Orb.ToWat do
    def to_wat(%Orb.Data{offset: offset, value: value}, indent) do
      [
        indent,
        "(data (i32.const ",
        to_string(offset),
        ") ",
        case value do
          string when is_binary(string) ->
            # string |> String.replace(~S["], ~S[\"]) |> String.replace("\n", ~S"\n")
            string
            |> inspect(binaries: :as_strings, limit: :infinity, printable_limit: :infinity)
            |> String.replace(~S|\0|, ~S|\00|)
            |> String.replace(~s[\\x], ~s[\\])

          list when is_list(list) ->
            for option <- list do
              case option do
                {:u8, bytes} ->
                  for byte <- List.wrap(bytes), do: encode_byte(byte)

                {:u32, u32s} ->
                  for u32 <- List.wrap(u32s) do
                    <<a::8, b::8, c::8, d::8>> = <<u32::little-size(32)>>

                    [
                      encode_byte(a),
                      encode_byte(b),
                      encode_byte(c),
                      encode_byte(d)
                    ]
                  end
              end
            end
            |> then(&[?", &1, ?"])
        end,
        ")\n"
      ]
    end

    defp encode_byte(byte) do
      [
        ?\\,
        byte |> Integer.to_string(16) |> String.downcase(:ascii) |> String.pad_leading(2, "0")
      ]
    end
  end

  defimpl Orb.ToWasm do
    def to_wasm(
          %Orb.Data{offset: offset, value: value},
          context
        ) do
      value_encoded =
        case value do
          string when is_binary(string) ->
            string

          list when is_list(list) ->
            for option <- list do
              case option do
                {:u8, bytes} ->
                  bytes

                {:u32, u32s} ->
                  for u32 <- List.wrap(u32s) do
                    # <<a::8, b::8, c::8, d::8>> = <<u32::little-size(32)>>
                    # [a, b, c, d]
                    <<u32::little-size(32)>>
                  end
              end
            end
        end

      [
        # active
        0x0,
        Orb.Instruction.Const.wrap(:i32, offset)
        |> Orb.ToWasm.to_wasm(context),
        # end opcode
        0x0B,
        Orb.ToWasm.Helpers.sized(value_encoded)
      ]
    end
  end
end
