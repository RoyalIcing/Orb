defmodule Orb.Data do
  @moduledoc false

  defstruct [:offset, :value, :nul_terminated]

  defimpl Orb.ToWat do
    def to_wat(%Orb.Data{offset: offset, value: value, nul_terminated: nul_terminated}, indent) do
      [
        indent,
        "(data (i32.const ",
        to_string(offset),
        ") ",
        ?",
        case value do
          string when is_binary(string) ->
            string |> String.replace(~S["], ~S[\"]) |> String.replace("\n", ~S"\n")

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
        end,
        ?",
        if(nul_terminated, do: ~S| "\00"|, else: []),
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
end
