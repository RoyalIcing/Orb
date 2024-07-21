defmodule WasmOutputTest do
  alias OrbWasmtime.Wasm
  use ExUnit.Case, async: true

  @moduletag timeout: 1_000

  test "basic module" do
    defmodule Basic do
      use Orb

      defw answer(), I32 do
        42
      end
    end

    assert <<"\0asm", 0x01000000::32>> <>
             <<0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7F>> <>
             <<0x03, 0x02, 0x01, 0x00>> <>
             <<0x07, 0x0A, 0x01, 0x06, "answer", 0x00, 0x00>> <>
             <<0x0A, 0x06, 0x01, 0x04, 0x00, <<0x41, 42>>, 0x0B>> =
             Orb.to_wasm(Basic)
  end

  test "conditionals" do
    defmodule Conditionals do
      use Orb

      defw is_odd?(n: I32), I32 do
        if I32.rem_u(n, 2) === 1 do
          1
        else
          0
        end
      end
    end

    wasm = Orb.to_wasm(Conditionals)

    assert wasm |> Wasm.call(:is_odd?, 0) === 0
    assert wasm |> Wasm.call(:is_odd?, 1) === 1
    assert wasm |> Wasm.call(:is_odd?, 2) === 0
    assert wasm |> Wasm.call(:is_odd?, 3) === 1
    assert wasm |> Wasm.call(:is_odd?, 4) === 0
    assert wasm |> Wasm.call(:is_odd?, 5) === 1
  end

  # test "encoding negative i32"

  test "i32 operations and func params" do
    defmodule MathI32 do
      use Orb

      defw math(a: I32, b: I32), I32, denominator: I32 do
        denominator = 4 + a - b
        a * b / denominator
      end

      defw fibonacci(n: I32), I32, a: I32, b: I32 do
        if n <= 1 do
          n
        else
          a = 0
          b = 1

          loop Each do
            b =
              Orb.Stack.push a + b do
                a = b
              end

            n = n - 1

            if n > 1 do
              Each.continue()
            end
          end

          b
        end
      end
    end

    wat = Orb.to_wat(MathI32)
    wasm = Orb.to_wasm(MathI32)

    assert wat |> Wasm.call(:fibonacci, 0) === 0
    assert wat |> Wasm.call(:fibonacci, 1) === 1
    assert wat |> Wasm.call(:fibonacci, 2) === 1
    assert wat |> Wasm.call(:fibonacci, 3) === 2
    assert wat |> Wasm.call(:fibonacci, 4) === 3
    assert wat |> Wasm.call(:fibonacci, 5) === 5
    assert wat |> Wasm.call(:fibonacci, 6) === 8
    assert wat |> Wasm.call(:fibonacci, 7) === 13

    assert wat === ~S"""
           (module $MathI32
             (func $math (export "math") (param $a i32) (param $b i32) (result i32)
               (local $denominator i32)
               (i32.sub (i32.add (i32.const 4) (local.get $a)) (local.get $b))
               (local.set $denominator)
               (i32.div_s (i32.mul (local.get $a) (local.get $b)) (local.get $denominator))
             )
             (func $fibonacci (export "fibonacci") (param $n i32) (result i32)
               (local $a i32)
               (local $b i32)
               (i32.le_s (local.get $n) (i32.const 1))
               (if (result i32)
                 (then
                   (local.get $n)
                 )
                 (else
                   (i32.const 0)
                   (local.set $a)
                   (i32.const 1)
                   (local.set $b)
                   (loop $Each
                     (i32.add (local.get $a) (local.get $b))
                     (local.get $b)
                     (local.set $a)

                     (local.set $b)
                     (i32.sub (local.get $n) (i32.const 1))
                     (local.set $n)
                     (i32.gt_s (local.get $n) (i32.const 1))
                     (if
                       (then
                         (br $Each)
                       )
                     )
                   )
                   (local.get $b)
                 )
               )
             )
           )
           """

    if false do
      path_wat = Path.join(__DIR__, "math.wat")
      path_wasm = Path.join(__DIR__, "math.wasm")
      File.write!(path_wat, wat)
      File.write!(path_wasm, wasm)
    end

    # assert <<"\0asm", 0x01000000::32>> <>
    #          <<0x01, 0x0C, 0x02, <<0x60, 0x02, 0x7F, 0x7F, 0x01, 0x7F>>,
    #            (<<0x60, 0x01, 0x7F, 0x01, 0x7F>>)>> <>
    #          <<0x03, 0x03, 0x02, 0x00, 0x01>> <>
    #          <<0x07, 0x14, 0x02, <<0x04, "math", 0x00, 0x00>>,
    #            (<<0x09, "fibonacci", 0x00, 0x01>>)>> <>
    #          <<0x0A, 0x18, 0x01, 0x16, <<0x01, 0x01, 0x7F>>,
    #            <<"", <<0x41, 0x04>>, <<0x20, 0x00>>, 0x6A, <<0x20, 0x01>>, 0x6B>>, <<0x21, 0x02>>,
    #            <<"", <<0x20, 0x00>>, <<0x20, 0x01>>, 0x6C, <<0x20, 0x02>>, 0x6D>>,
    #            0x0B>> =
    #          wasm

    # extract_wasm_sections(wasm) |> dbg(base: :hex, limit: 1000)

    assert (11 * 7) |> div(4 + 11 - 7) === 9
    assert wat |> Wasm.call(:math, 11, 7) === 9
    assert wasm |> Wasm.call(:math, 11, 7) === 9
  end

  test "i64 operations and func params" do
    defmodule MathI64 do
      use Orb

      defw math(a: I64, b: I64), I64, denominator: I64 do
        denominator = 4 + a - b
        a * b / denominator
      end
    end

    assert ~S"""
           (module $MathI64
             (func $math (export "math") (param $a i64) (param $b i64) (result i64)
               (local $denominator i64)
               (i64.sub (i64.add (i64.const 4) (local.get $a)) (local.get $b))
               (local.set $denominator)
               (i64.div_s (i64.mul (local.get $a) (local.get $b)) (local.get $denominator))
             )
           )
           """ === Orb.to_wat(MathI64)

    assert <<"\0asm", 0x01000000::32>> <>
             <<0x01, 0x07, 0x01, (<<0x60, 0x02, 0x7E, 0x7E, 0x01, 0x7E>>)>> <>
             <<0x03, 0x02, 0x01, 0x00>> <>
             <<0x07, 0x08, 0x01, 0x04, "math", 0x00, 0x00>> <>
             <<0x0A, 0x18, 0x01, 0x16, <<0x01, 0x01, 0x7E>>,
               <<"", <<0x42, 0x04>>, <<0x20, 0x00>>, 0x7C, <<0x20, 0x01>>, 0x7D>>, <<0x21, 0x02>>,
               <<"", <<0x20, 0x00>>, <<0x20, 0x01>>, 0x7E, <<0x20, 0x02>>, 0x7F>>,
               0x0B>> ===
             Orb.to_wasm(MathI64)

    assert (11 * 7) |> div(4 + 11 - 7) === 9
    assert Orb.to_wat(MathI64) |> Wasm.call(:math, {:i64, 11}, {:i64, 7}) === 9
    assert Orb.to_wasm(MathI64) |> Wasm.call(:math, {:i64, 11}, {:i64, 7}) === 9
  end

  defp extract_wasm_sections(<<"\0asm", 0x01000000::32>> <> bytes) do
    extract_wasm_section(bytes, [])
  end

  defp extract_wasm_section(<<>>, list) do
    list |> :lists.reverse()
  end

  defp extract_wasm_section(<<type::8, len::8, section::binary-size(len), rest::binary>>, list) do
    extract_wasm_section(rest, [do_wasm_type(type, section) | list])
  end

  defp do_wasm_type(0x01, <<count::8, section::binary>>) do
    section
    |> :binary.split("\x60", [:global])
    |> Enum.reject(&(&1 == ""))
    |> then(fn items when length(items) === count ->
      {:type, items}
    end)
  end

  defp do_wasm_type(0x03, section), do: {:function, section}
  defp do_wasm_type(0x07, section), do: {:export, section}
  # defp do_wasm_type(0x0A, <<count::8, section::binary>>), do: {:code, {count, section}}
  defp do_wasm_type(0x0A, <<count::8, section::binary>>) do
    for <<len::8, func_code::binary-size(len) <- section>> do
      {func_code}
    end
    |> then(fn items when length(items) === count ->
      {:code, items}
    end)
  end

  defp do_wasm_type(type, section), do: {type, section}
end
