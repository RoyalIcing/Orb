defmodule I32StringTest do
  use ExUnit.Case, async: true

  alias OrbWasmtime.{Instance, Wasm}
  alias Orb.I32

  test "wasm size" do
    wasm = Wasm.to_wasm(I32.String)
    assert byte_size(wasm) == 152
  end

  test "strlen" do
    inst = Instance.run(I32.String)
    strlen = Instance.capture(inst, :strlen, 1)

    Instance.write_string_nul_terminated(inst, 0x00100, "hello")
    Instance.write_string_nul_terminated(inst, 0x00200, "me")
    assert strlen.(0x00100) == 5
    assert strlen.(0x00200) == 2
    assert strlen.(0x00300) == 0
  end

  test "streq" do
    inst = Instance.run(I32.String)
    streq = Instance.capture(inst, :streq, 2)

    Instance.write_string_nul_terminated(inst, 0x00100, "hello")
    Instance.write_string_nul_terminated(inst, 0x00200, "world")
    assert streq.(0x00100, 0x00200) == 0

    Instance.write_string_nul_terminated(inst, 0x00100, "hello")
    Instance.write_string_nul_terminated(inst, 0x00200, "hello")
    assert streq.(0x00100, 0x00200) == 1

    Instance.write_string_nul_terminated(inst, 0x00100, "hellp")
    Instance.write_string_nul_terminated(inst, 0x00200, "hello")
    assert streq.(0x00100, 0x00200) == 0

    Instance.write_string_nul_terminated(inst, 0x00100, "hi\0\0\0")
    Instance.write_string_nul_terminated(inst, 0x00200, "hip\0\0")
    assert streq.(0x00100, 0x00200) == 0

    Instance.write_string_nul_terminated(inst, 0x00100, "hip\0\0")
    Instance.write_string_nul_terminated(inst, 0x00200, "hi\0\0\0")
    assert streq.(0x00100, 0x00200) == 0

    Instance.write_string_nul_terminated(inst, 0x00100, "\0\0\0\0\0")
    Instance.write_string_nul_terminated(inst, 0x00200, "\0\0\0\0\0")
    assert streq.(0x00100, 0x00200) == 1

    Instance.write_string_nul_terminated(inst, 0x00100, "h\0\0\0\0")
    Instance.write_string_nul_terminated(inst, 0x00200, "\0\0\0\0\0")
    assert streq.(0x00100, 0x00200) == 0

    Instance.write_string_nul_terminated(inst, 0x00100, "\0\0\0\0\0")
    Instance.write_string_nul_terminated(inst, 0x00200, "h\0\0\0\0")
    assert streq.(0x00100, 0x00200) == 0

    assert streq.(0x00300, 0x00400) == 1
  end
end
