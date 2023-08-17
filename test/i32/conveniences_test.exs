defmodule I32ConveniencesTest do
  use ExUnit.Case, async: true

  alias OrbWasmtime.Wasm

  defmodule URLEncoding do
    use Orb

    defw is_url_safe?(char: I32.U8), I32 do
      I32.in_inclusive_range?(char, ?a, ?z) or
        I32.in_inclusive_range?(char, ?A, ?Z) or
        I32.in_inclusive_range?(char, ?0, ?9) or
        I32.in?(char, ~C{~_-.})
    end
  end

  test "url safe characters" do
    assert Wasm.call(URLEncoding, :is_url_safe?, ?a) == 1
    assert Wasm.call(URLEncoding, :is_url_safe?, ?z) == 1
    assert Wasm.call(URLEncoding, :is_url_safe?, ?~) == 1
    assert Wasm.call(URLEncoding, :is_url_safe?, ?_) == 1
    assert Wasm.call(URLEncoding, :is_url_safe?, ?-) == 1
    assert Wasm.call(URLEncoding, :is_url_safe?, ?.) == 1
  end

  test "url unsafe characters" do
    assert Wasm.call(URLEncoding, :is_url_safe?, ??) == 0
    assert Wasm.call(URLEncoding, :is_url_safe?, ?/) == 0
    assert Wasm.call(URLEncoding, :is_url_safe?, ?*) == 0
  end
end
