defmodule I32ConveniencesTest do
  use ExUnit.Case, async: true

  alias OrbWasmtime.Wasm

  defmodule URLEncoding do
    use Orb

    defw is_url_safe?(char: I32.U8), I32 do
      (char >= ?a &&& char <= ?z) or
        (char >= ?A &&& char <= ?Z) or
        (char >= ?0 &&& char <= ?9) or
        I32.in?(char, ~C{~_-.})

      # I32.in_inclusive_range?(char, ?a, ?z) or
      #   I32.in_inclusive_range?(char, ?A, ?Z) or
      #   I32.in_inclusive_range?(char, ?0, ?9) or
      #   I32.in?(char, ~C{~_-.})
    end

    defw is_abc?(char: I32.U8), I32 do
      I32.match char do
        ?a -> 1
        ?b -> 1
        ?c -> 1
        _ -> 0
      end
    end
  end

  test "url safe characters" do
    assert Wasm.call(URLEncoding, :is_url_safe?, ?a) == 1
    assert Wasm.call(URLEncoding, :is_url_safe?, ?z) == 1
    assert Wasm.call(URLEncoding, :is_url_safe?, ?A) == 1
    assert Wasm.call(URLEncoding, :is_url_safe?, ?Z) == 1
    assert Wasm.call(URLEncoding, :is_url_safe?, ?0) == 1
    assert Wasm.call(URLEncoding, :is_url_safe?, ?9) == 1
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
