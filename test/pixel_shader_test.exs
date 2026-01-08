defmodule PixelShaderTest do
  use ExUnit.Case, async: true

  test "checkerbox" do
    defmodule Checkerbox do
      use Orb

      Memory.pages(5)

      defw pixel_buffer_bounds(), {I32, I32} do
        {0x10_000, 4 * 256 * 256}
      end

      defw render() do
        loop y <- 0..255 do
          loop x <- 0..255 do
            # Memory.store!(I32, 0x10_000 + y * 256 * 4 + x * 4, i32(0xFF9900FF))
            Memory.store!(I32, 0x10_000 + y * 256 * 4 + x * 4, render_pixel(x, y))
          end
        end
      end

      defwp render_pixel(x: I32, y: I32), I32 do
        (I32.div_u(x, 10) + I32.div_u(y, 10) &&&
           1)
        |> if(select: I32, do: i32(0x0099FFFF), else: i32(0xFF9900FF))
      end

      # defwp render_pixel(x: I32, y: I32), I32 do
      #   if I32.div_u(x, 10) + I32.div_u(y, 10) &&& 1 do
      #     0x0099FFFF
      #   else
      #     0xFF9900FF
      #   end
      # end
    end

    IO.puts(Orb.to_wat(Checkerbox))

    bmp_header = [
      # Bitmap file header
      # Signature
      "BM",
      # File size
      <<54 + 256 * 256 * 4::little-size(32)>>,
      # Reserved1
      <<0::little-size(16)>>,
      # Reserved2
      <<0::little-size(16)>>,
      # Offset to pixel data
      <<54::little-size(32)>>,

      # DIB header (BITMAPINFOHEADER)
      # DIB header size
      <<40::little-size(32)>>,
      # Width
      <<256::little-size(32)>>,
      # Height
      <<256::little-size(32)>>,
      # Color planes
      <<1::little-size(16)>>,
      # Bits per pixel
      <<32::little-size(16)>>,
      # Compression (none)
      <<0::little-size(32)>>,
      # Image size
      <<256 * 256 * 4::little-size(32)>>,
      # Horizontal resolution (pixels per meter)
      <<2835::little-size(32)>>,
      # Vertical resolution (pixels per meter)
      <<2835::little-size(32)>>,
      # Number of colors in palette
      <<0::little-size(32)>>,
      # Important colors
      <<0::little-size(32)>>
    ]

    wat = Orb.to_wat(Checkerbox)
    # Compile WebAssembly using Wasmex
    imports = %{}
    {:ok, pid} = Wasmex.start_link(%{bytes: wat, imports: imports})
    {:ok, memory} = Wasmex.memory(pid)
    {:ok, store} = Wasmex.store(pid)
    # Run render function
    # Time render function
    tc("wasm", fn -> Wasmex.call_function(pid, :render, []) end)
    # {:ok, _} = Wasmex.call_function(pid, :render, [])
    # Read bytes
    bitmap = Wasmex.Memory.read_binary(store, memory, 0x10_000, 256 * 256 * 4)

    dbg(bitmap)
    dbg(byte_size(bitmap))

    bitmap2 =
      tc("elixir", fn ->
        for y <- 0..255 do
          for x <- 0..255 do
            # Four bytes of data
            # <<0xFF9900FF::integer-size(32)-little>>
            if Integer.mod(x, 20) >= 10 do
              <<0x0099FFFF::integer-size(32)-little>>
            else
              <<0xFF9900FF::integer-size(32)-little>>
            end
          end
        end
      end)

    # dbg(bitmap2)
    # dbg(IO.iodata_length(bitmap2))
    # dbg(byte_size(IO.iodata_to_binary(bitmap2)))

    filename = Path.join(__DIR__, "pixel_shader_test.bmp")
    File.write!(filename, [bmp_header, bitmap])
  end

  defp tc(label, f) when is_binary(label) and is_function(f, 0) do
    {duration_microseconds, result} = :timer.tc(f)
    IO.puts("#{label} #{duration_microseconds} microseconds")
    result
  end
end
