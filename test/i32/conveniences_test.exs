defmodule I32ConveniencesTest do
  use ExUnit.Case, async: true
  use OrbHelper

  alias OrbWasmtime.Wasm

  defmodule URLEncoding do
    use Orb

    defw is_url_safe?(char: I32.U8), I32 do
      (char >= ?a &&& char <= ?z) or
        (char >= ?A &&& char <= ?Z) or
        (char >= ?0 &&& char <= ?9) or
        I32.in?(char, [?~, ?_, ?-, ?.])
        # I32.in?(char, ~C{~_-.})

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

  defmodule Attrs do
    use Orb

    I32.global(first: 7)

    wasm do
      I32.attr_writer(:first)
    end
  end

  test "attr_writer works" do
    assert Attrs.to_wat() === """
    (module $Attrs
      (global $first (mut i32) (i32.const 7))
      (func $first= (export "first=") (param $new_value i32)
        (local.get $new_value)
        (global.set $first)
      )
    )
    """

    assert Wasm.call(Attrs, :"first=", 9) == nil
  end

  test "I32.match output int" do
    assert (OrbHelper.module_wat do
      use Orb

      defw get_path(), I32.String, state: I32 do
        state = 0

        I32.match state do
          0 -> 100
          1 -> 200
        end
      end
    end) =~ "(i32.const 100)"
  end

  test "I32.match output string constant" do
    assert (OrbHelper.module_wat do
      use Orb

      defw get_path(), I32.String, state: I32 do
        state = 0

        I32.match state do
          0 -> ~S[/initial]
          1 -> ~S[/disconnected]
        end
      end
    end) =~ "/initial"
  end
end
