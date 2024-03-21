defmodule IfElseTest do
  use ExUnit.Case, async: true

  import Orb, only: [to_wat: 1]

  test "no inferred type" do
    defmodule A do
      use Orb

      global :export_mutable do
        @a 0
      end

      defw test() do
        if i32(0) do
          @a = 1
        else
          @a = 2
        end
      end
    end

    assert """
           (module $A
             (global $a (export "a") (mut i32) (i32.const 0))
             (func $test (export "test")
               (i32.const 0)
               (if
                 (then
                   (i32.const 1)
                   (global.set $a)
                 )
                 (else
                   (i32.const 2)
                   (global.set $a)
                 )
               )
             )
           )
           """ === to_wat(A)
  end

  test "inferred i32" do
    defmodule InferredI32_A do
      use Orb

      defw test(), I32 do
        if i32(0) do
          1
        else
          2
        end
      end
    end

    defmodule InferredI32_B do
      use Orb

      defw test(), I32 do
        if i32(0), do: 1, else: 2
      end
    end

    defmodule InferredI32_C do
      use Orb

      defw test(), I32 do
        if i32(0) do
          1
        else
          i32(2)
        end
      end
    end

    defmodule InferredI32_D do
      use Orb

      defw test(), I32 do
        if i32(0) do
          i32(1)
        else
          i32(2)
        end
      end
    end

    wat =
      """
        (func $test (export "test") (result i32)
          (i32.const 0)
          (if (result i32)
            (then
              (i32.const 1)
            )
            (else
              (i32.const 2)
            )
          )
        )
      )
      """

    assert to_wat(InferredI32_A) =~ wat
    assert to_wat(InferredI32_B) =~ wat
    assert to_wat(InferredI32_C) =~ wat
    assert to_wat(InferredI32_D) =~ wat
  end

  test "inferred i64" do
    defmodule InferredI64_A do
      use Orb

      defw test(), I64 do
        if i64(0) do
          1
        else
          2
        end
      end
    end

    defmodule InferredI64_B do
      use Orb

      defw test(), I64 do
        if i64(0), do: 1, else: 2
      end
    end

    defmodule InferredI64_C do
      use Orb

      defw test(), I64 do
        if i64(0) do
          i64(1)
        else
          2
        end
      end
    end

    defmodule InferredI64_D do
      use Orb

      defw test(), I64 do
        if i64(0) do
          i64(1)
        else
          i64(2)
        end
      end
    end

    wat =
      """
        (func $test (export "test") (result i64)
          (i64.const 0)
          (if (result i64)
            (then
              (i64.const 1)
            )
            (else
              (i64.const 2)
            )
          )
        )
      )
      """

    assert to_wat(InferredI64_A) =~ wat
    assert to_wat(InferredI64_B) =~ wat
    assert to_wat(InferredI64_C) =~ wat
    assert to_wat(InferredI64_D) =~ wat
  end

  test "local effect" do
    defmodule URLSearchParams do
      use Orb

      Memory.pages(1)

      defw url_search_params_count(url_params: I32.U8.UnsafePointer), I32,
        char: I32.U8,
        count: I32,
        pair_char_len: I32 do
        loop EachByte do
          char = url_params[at!: 0]

          if I32.in?(char, [?&, ?\0]) do
            count = count + (pair_char_len > 0)
            pair_char_len = 0
          else
            pair_char_len = pair_char_len + 1
          end

          url_params = url_params + 1

          EachByte.continue(if: char)
        end

        count
      end
    end

    alias OrbWasmtime.Instance
    inst = Instance.run(URLSearchParams)
    count = Instance.capture(inst, :url_search_params_count, 1)

    Instance.write_string_nul_terminated(inst, 0x00100, "")
    assert count.(0x00100) == 0

    Instance.write_string_nul_terminated(inst, 0x00100, "a=1")
    assert count.(0x00100) == 1

    Instance.write_string_nul_terminated(inst, 0x00100, "a=1&b=1")
    assert count.(0x00100) == 2

    Instance.write_string_nul_terminated(inst, 0x00100, "a=1&")
    assert count.(0x00100) == 1

    Instance.write_string_nul_terminated(inst, 0x00100, "&a=1&")
    assert count.(0x00100) == 1

    Instance.write_string_nul_terminated(inst, 0x00100, "&a=1&&&b=2")
    assert count.(0x00100) == 2
  end

  test "local and unknown effect" do
    defmodule URLSearchParams2 do
      use Orb

      Memory.pages(1)

      defmodule Log do
        use Orb.Import

        defw(found_alphanumeric(), nil)
      end

      importw(Log, :log)

      defw url_search_params_count(url_params: I32.U8.UnsafePointer), I32,
        char: I32.U8,
        count: I32,
        pair_char_len: I32 do
        loop EachByte do
          char = url_params[at!: 0]

          if I32.in?(char, [?&, ?\0]) do
            count = count + (pair_char_len > 0)
            pair_char_len = 0
          else
            pair_char_len = pair_char_len + 1
            Log.found_alphanumeric()
          end

          url_params = url_params + 1

          EachByte.continue(if: char)
        end

        count
      end
    end

    alias OrbWasmtime.Instance

    inst =
      Instance.run(URLSearchParams2, [
        {:log, :found_alphanumeric, fn -> nil end}
      ])

    count = Instance.capture(inst, :url_search_params_count, 1)

    Instance.write_string_nul_terminated(inst, 0x00100, "")
    assert count.(0x00100) == 0

    Instance.write_string_nul_terminated(inst, 0x00100, "a=1")
    assert count.(0x00100) == 1

    Instance.write_string_nul_terminated(inst, 0x00100, "a=1&b=1")
    assert count.(0x00100) == 2

    Instance.write_string_nul_terminated(inst, 0x00100, "a=1&")
    assert count.(0x00100) == 1

    Instance.write_string_nul_terminated(inst, 0x00100, "&a=1&")
    assert count.(0x00100) == 1

    Instance.write_string_nul_terminated(inst, 0x00100, "&a=1&&&b=2")
    assert count.(0x00100) == 2
  end

  test "chain onto existing if/else" do
    defmodule Chain do
      use Orb

      global :mutable do
        @a 0
      end

      defw test() do
        if i32(0) do
          @a = i32(1)
        else
          @a = i32(2)
        end
        |> if do
          @a = i32(7)
        end
        |> if do
          @a = i32(42)
        end
      end
    end

    assert """
           (module $Chain
             (global $a (mut i32) (i32.const 0))
             (func $test (export "test")
               (i32.const 0)
               (if
                 (then
                   (i32.const 1)
                   (global.set $a)
                   (i32.const 7)
                   (global.set $a)
                   (i32.const 42)
                   (global.set $a)
                 )
                 (else
                   (i32.const 2)
                   (global.set $a)
                 )
               )
             )
           )
           """ === to_wat(Chain)
  end
end
