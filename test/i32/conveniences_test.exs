defmodule I32ConveniencesTest do
  use ExUnit.Case, async: true
  require TestHelper

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
    wat = Orb.to_wat(URLEncoding)
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?a) == 1
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?z) == 1
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?A) == 1
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?Z) == 1
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?0) == 1
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?9) == 1
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?~) == 1
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?_) == 1
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?-) == 1
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?.) == 1
  end

  test "url unsafe characters" do
    wat = Orb.to_wat(URLEncoding)
    assert TestHelper.wasm_call(wat, :is_url_safe?, ??) == 0
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?/) == 0
    assert TestHelper.wasm_call(wat, :is_url_safe?, ?*) == 0
  end

  test "I32.cond without catch-all" do
    assert (TestHelper.module_wat do
              use Orb

              defw get_path(), I32, state: I32 do
                state = 0

                I32.cond do
                  state === 0 -> i32(100)
                  state === 1 -> i32(200)
                end
              end
            end) == """
           (module $Sample
             (func $get_path (export "get_path") (result i32)
               (local $state i32)
               (i32.const 0)
               (local.set $state)
               (block $i32_cond_60 (result i32)
                 (i32.eq (local.get $state) (i32.const 0))
                 (if (result i32)
                   (then
                     (i32.const 100)
                     (br $i32_cond_60)
                   )
                 )
                 (i32.eq (local.get $state) (i32.const 1))
                 (if (result i32)
                   (then
                     (i32.const 200)
                     (br $i32_cond_60)
                   )
                 )
                 unreachable
               )
             )
           )
           """
  end

  test "I32.cond with catch-all" do
    wat =
      TestHelper.module_wat do
        use Orb

        defw get_path(), I32, state: I32 do
          state = 0

          I32.cond do
            state === 0 -> i32(100)
            state === 1 -> i32(200)
            true -> i32(500)
          end
        end
      end

    # Test that the WAT contains the expected structure (ignoring auto-generated label numbers)
    assert wat =~ "(module $Sample"
    assert wat =~ "(func $get_path (export \"get_path\") (result i32)"
    assert wat =~ "(local $state i32)"
    assert wat =~ "(i32.const 0)"
    assert wat =~ "(local.set $state)"
    assert wat =~ ~r/\(block \$i32_cond_\d+ \(result i32\)/
    assert wat =~ "(i32.eq (local.get $state) (i32.const 0))"
    assert wat =~ "(i32.const 100)"
    assert wat =~ "(i32.eq (local.get $state) (i32.const 1))"
    assert wat =~ "(i32.const 200)"
    assert wat =~ "(i32.const 500)"
  end

  test "I32.match output int" do
    assert (TestHelper.module_wat do
              use Orb

              defw get_path(), I32, state: I32 do
                state = 0

                I32.match state do
                  0 -> 100
                  1 -> 200
                end
              end
            end) =~ "(i32.const 100)"
  end

  test "I32.match output string constant" do
    wat =
      TestHelper.module_wat do
        use Orb

        defw get_path(), Str, state: I32 do
          state = 0

          I32.match state do
            0 -> ~S[/initial]
            1 -> ~S[/disconnected]
          end
        end
      end

    assert wat =~ "/initial"

    # TODO: compile to check we actually return (i32 i32) for each Str.
  end

  test "can return string constant" do
    wat =
      TestHelper.module_wat do
        use Orb

        global do
          @method "GET"
        end

        defw ptr(), I32 do
          @method |> Memory.Slice.get_byte_offset()
        end

        defw text_html(), Str do
          if Memory.load!(I32, @method |> Memory.Slice.get_byte_offset()) !==
               I32.from_4_byte_ascii("GET\0") do
            return(~S"""
            <!doctype html>
            <h1>Method not allowed</h1>
            """)
          end

          "<p>Hello</p>"
        end
      end

    assert wat =~ "Method not allowed"

    assert 255 = TestHelper.wasm_call(wat, :ptr)

    assert "<p>Hello</p>" =
             TestHelper.wasm_call_reading_string(wat, :text_html)
  end

  test "I32.sum!" do
    assert 30 =
             (TestHelper.module_wat do
                use Orb

                defwp(ten(), I32, do: 10)

                defw sum(), I32 do
                  I32.sum!([
                    byte_size("hello"),
                    byte_size("beautiful"),
                    byte_size("world"),
                    if(ten(), do: 1, else: 200),
                    ten()
                  ])
                end
              end)
             |> TestHelper.wasm_call(:sum)
  end
end
