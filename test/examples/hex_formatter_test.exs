defmodule Examples.HexFormatterTest do
  use ExUnit.Case, async: true

  Code.require_file("hex_formatter.exs", __DIR__)
  alias Examples.HexFormatter

  # TODO: Migrate to Wasmex - needs implementation of:
  # - Instance.capture for function references
  # - Instance.read_memory for reading from WASM memory
  # - Stateful instance management with memory operations
  
  test "u32_to_hex_lower" do
    # IO.puts(HexFormatter.to_wat())

    # inst = Instance.run(HexFormatter)
    # u32_to_hex_lower = Instance.capture(inst, :u32_to_hex_lower, 2)
    # read = &Instance.read_memory(inst, &1, 8)

    # u32_to_hex_lower.(0x00000000, 0x100)
    # assert read.(0x100) == "00000000"

    # u32_to_hex_lower.(255, 0x100)
    # assert read.(0x100) == "000000ff"

    # u32_to_hex_lower.(0x00ABCDEF, 0x100)
    # assert read.(0x100) == "00abcdef"

    # u32_to_hex_lower.(0x44ABCDEF, 0x100)
    # assert read.(0x100) == "44abcdef"

    # u32_to_hex_lower.(0xFFFF_FFFF, 0x100)
    # assert read.(0x100) == "ffffffff"

    # u32_to_hex_lower.(1, 0x100)
    # assert read.(0x100) == "00000001"

    # # Does NOT write outside its bounds.
    # assert Instance.read_memory(inst, 0x100 - 1, 1) == <<0>>
    # assert Instance.read_memory(inst, 0x100 + 9, 1) == <<0>>
  end
end
