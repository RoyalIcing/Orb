defmodule ParserTest do
  use ExUnit.Case, async: true

  defmodule CharParser do
    use Orb

    def may(chars, offset_mut_ref) when is_list(chars) do
      Orb.snippet do
        chars
        |> Enum.with_index(fn char, index ->
          Memory.load!(I32.U8, offset_mut_ref.read + index) === char
        end)
        |> Enum.reduce(&I32.band/2)
        |> if do
          offset_mut_ref.read + length(chars)
          offset_mut_ref.write
        end
      end
    end

    def must(chars, offset_mut_ref, fail_instruction) when is_list(chars) do
      Orb.snippet do
        may(chars, offset_mut_ref)
        |> unless do
          fail_instruction
        end
      end
    end

    # Future API?
    # CharParser.seq(mut!(input_offset), return(0), must: ~c|http|, may: ~c|s|, must: ~c|:|, may: ~c|//|)

    # Future API?
    # CharParser.one_of([
    #   [may: ~c|www.|, must: ~c|youtube.com|], must: ~c|/watch?v=|],
    #   [must: ~c|youtu.be/|]
    # ], mut!(input_offset), return(0))

    def print(ast) do
      IO.puts(Orb.ToWat.to_wat(ast, "") |> IO.iodata_to_binary())
    end
  end

  defmodule YouTubeURLParser do
    use Orb

    Memory.pages(1)

    defmodule Input.Values do
      def start_page_offset(), do: 0x0
    end

    defw parse(), I32, input_offset: I32 do
      input_offset = Input.Values.start_page_offset() * Memory.page_byte_size()

      Control.block OptionalScheme do
        CharParser.must(~c|http|, mut!(input_offset), OptionalScheme.break())
        CharParser.may(~c|s|, mut!(input_offset))
        CharParser.must(~c|:|, mut!(input_offset), OptionalScheme.break())
      end

      CharParser.may(~c|//|, mut!(input_offset))

      Control.block ShortDomain do
        push(input_offset)

        Control.block FullDomain do
          CharParser.may(~c|www.|, mut!(input_offset))
          CharParser.must(~c|youtube.com|, mut!(input_offset), FullDomain.break())
          CharParser.must(~c|/watch?v=|, mut!(input_offset), FullDomain.break())
          ShortDomain.break()
        end

        input_offset = Orb.Stack.pop(I32)

        CharParser.must(~c|youtu.be/|, mut!(input_offset), return(0))
      end

      input_offset
    end
  end

  test "works" do
    alias OrbWasmtime.Instance

    wat = Orb.to_wat(YouTubeURLParser)
    # IO.puts(wat)
    inst = Instance.run(wat)
    Instance.call(inst, :parse)
    # assert "" === wat
  end
end
