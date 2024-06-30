defmodule Examples.YoutubeParserTest do
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
        unless may(chars, offset_mut_ref) do
          fail_instruction
        end
      end
    end
  end

  defmodule YouTubeURLParser do
    use Orb

    # alias require SilverOrb.Arena
    # Arena.def(Input, pages: 1)

    Memory.pages(2)

    defmodule Input.Values do
      def start_page_offset(), do: 1
    end

    defw(input_offset(), I32, do: Input.Values.start_page_offset() * Memory.page_byte_size())

    defw parse(), I32, input_offset: I32.UnsafePointer do
      input_offset = Input.Values.start_page_offset() * Memory.page_byte_size()

      # input_offset[~c|http|]

      Control.block OptionalScheme do
        CharParser.must(~c|http|, mut!(input_offset), OptionalScheme.break())
        # unless CharParser.may(~c|http|, mut!(input_offset)), do: OptionalScheme.break()
        CharParser.may(~c|s|, mut!(input_offset))
        CharParser.must(~c|:|, mut!(input_offset), OptionalScheme.break())
      end

      CharParser.may(~c|//|, mut!(input_offset))

      Control.block Final do
        Control.block ShortDomain do
          Orb.Stack.push(input_offset)

          Control.block FullDomain do
            CharParser.may(~c|www.|, mut!(input_offset))
            CharParser.must(~c|youtube.com|, mut!(input_offset), FullDomain.break())
            CharParser.must(~c|/watch?v=|, mut!(input_offset), FullDomain.break())
            unless input_offset[at!: 0], do: FullDomain.break()
            Final.break()
          end

          input_offset = Orb.Stack.pop(I32)

          CharParser.must(~c|youtu.be/|, mut!(input_offset), ShortDomain.break())
          unless input_offset[at!: 0], do: ShortDomain.break()
          Final.break()
        end

        return(0)
      end

      input_offset
    end

    def run(input) do
      alias OrbWasmtime.Instance

      wat = Orb.to_wat(__MODULE__)
      inst = Instance.run(wat)

      input_offset = Instance.call(inst, :input_offset)
      # Instance.write_memory(inst, input_offset, input <> "\0" |> :binary.bin_to_list())
      Instance.write_string_nul_terminated(inst, input_offset, input)

      result = Instance.call(inst, :parse)

      case result do
        0 ->
          nil

        offset ->
          Instance.read_memory(inst, offset, 255)
          |> String.replace_trailing("\0", "")
      end

      # {:ok, pid} = Wasmex.start_link(%{bytes: Orb.to_wat(__MODULE__)})
      # {:ok, memory} = Wasmex.memory(pid)
      # {:ok, store} = Wasmex.store(pid)

      # {:ok, [input_offset]} = Wasmex.call_function(pid, :input_offset, [])
      # Wasmex.Memory.write_binary(store, memory, input_offset, input <> "\0")

      # {:ok, [result]} = Wasmex.call_function(pid, :parse, [])

      # case result do
      #   0 ->
      #     nil

      #   offset ->
      #     Wasmex.Memory.read_string(store, memory, offset, 255)
      #     |> String.replace_trailing("\0", "")
      # end
    end
  end

  test "can parse valid YouTube URLs" do
    assert "hello" = YouTubeURLParser.run("http://www.youtube.com/watch?v=hello")
    assert "hello" = YouTubeURLParser.run("https://www.youtube.com/watch?v=hello")
    assert "hello" = YouTubeURLParser.run("https://youtube.com/watch?v=hello")
    assert "hello" = YouTubeURLParser.run("https://youtu.be/hello")
    assert "hello" = YouTubeURLParser.run("//www.youtube.com/watch?v=hello")
    assert "hello" = YouTubeURLParser.run("//youtu.be/hello")
    assert "hello" = YouTubeURLParser.run("www.youtube.com/watch?v=hello")
  end

  test "can ignore invalid YouTube URLs" do
    assert nil == YouTubeURLParser.run("www.youtu.be/watch?v=hello")
    assert nil == YouTubeURLParser.run("https://www.youtube.com/watch")
    assert nil == YouTubeURLParser.run("https://www.youtube.com/watch?v=")
    assert nil == YouTubeURLParser.run("https://youtu.be/")
    assert nil == YouTubeURLParser.run("hello")
  end
end
