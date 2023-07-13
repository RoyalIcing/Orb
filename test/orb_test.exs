defmodule OrbTest do
  use ExUnit.Case, async: true

  use Orb

  test "func" do
    wasm =
      func answer(), I32 do
        42
      end

    wasm_source = """
    (func $answer (export "answer") (result i32)
      (i32.const 42)
    )\
    """

    assert to_wat(wasm) == wasm_source
  end

  test "funcp" do
    wasm =
      funcp answer(), I32 do
        42
      end

    wasm_source = """
    (func $answer (result i32)
      (i32.const 42)
    )\
    """

    assert to_wat(wasm) == wasm_source
  end

  describe "globals" do
    test "I32" do
      defmodule GlobalsI32 do
        use Orb

        I32.global(abc: 42)
        I32.global(:readonly, CONST: 99)
        I32.export_global(:mutable, public1: 11)
        I32.export_global(:readonly, public2: 22)
      end

      assert to_wat(GlobalsI32) == """
             (module $GlobalsI32
               (global $abc (mut i32) (i32.const 42))
               (global $CONST i32 (i32.const 99))
               (global $public1 (export "public1") (mut i32) (i32.const 11))
               (global $public2 (export "public2") i32 (i32.const 22))
             )
             """
    end

    test "I32 enum" do
      defmodule GlobalsI32Enum do
        use Orb

        I32.enum([:first, :second])
        I32.enum([:restarts, :from, :zero])
        I32.enum([:third, :fourth], 2)
        I32.export_enum([:apples, :pears])
        I32.export_enum([:ok, :created, :accepted], 200)
      end

      assert to_wat(GlobalsI32Enum) == """
             (module $GlobalsI32Enum
               (global $first i32 (i32.const 0))
               (global $second i32 (i32.const 1))
               (global $restarts i32 (i32.const 0))
               (global $from i32 (i32.const 1))
               (global $zero i32 (i32.const 2))
               (global $third i32 (i32.const 2))
               (global $fourth i32 (i32.const 3))
               (global $apples (export "apples") i32 (i32.const 0))
               (global $pears (export "pears") i32 (i32.const 1))
               (global $ok (export "ok") i32 (i32.const 200))
               (global $created (export "created") i32 (i32.const 201))
               (global $accepted (export "accepted") i32 (i32.const 202))
             )
             """
    end
  end

  describe "memory" do
    test "Memory.pages/1" do
      defmodule Pages2 do
        use Orb

        Memory.pages(2)
      end

      assert to_wat(Pages2) == """
             (module $Pages2
               (memory (export "memory") 2)
             )
             """
    end

    test "3 x Memory.pages/1 takes the maximum" do
      defmodule TwicePages2 do
        use Orb

        Memory.pages(2)
        Memory.pages(3)
        Memory.pages(1)
      end

      assert to_wat(TwicePages2) == """
             (module $TwicePages2
               (memory (export "memory") 3)
             )
             """
    end
  end

  describe "imports" do
    test "can declare import" do
      defmodule ImportsLog32 do
        use Orb

        # Import.funcp(:log, :int32, as: :log_i32, params: I32, result: I32)
        # wasm_import(:log,
        #   int32: funcp(log_i32(I32), I32)
        # )

        wasm_import(:echo,
          int32: funcp(name: :echo_i32, params: I32, result: I32),
          int64: funcp(name: :echo_i64, params: I64, result: I64)
        )

        wasm_import(:log,
          int32: funcp(name: :log_i32, params: I32),
          int64: funcp(name: :log_i64, params: I64)
        )
      end

      assert to_wat(ImportsLog32) == """
             (module $ImportsLog32
               (import "echo" "int32" (func $echo_i32 (param i32) (result i32)))
               (import "echo" "int64" (func $echo_i64 (param i64) (result i64)))
               (import "log" "int32" (func $log_i32 (param i32)))
               (import "log" "int64" (func $log_i64 (param i64)))
             )
             """
    end
  end

  describe "~S" do
    test "assigns data" do
      defmodule HTMLTypes do
        use Orb

        wasm do
          func doctype(), I32 do
            ~S"<!doctype html>"
          end

          func mime_type(), I32 do
            ~S"text/html"
          end
        end
      end

      assert to_wat(HTMLTypes) == """
             (module $HTMLTypes
               (data (i32.const 255) "<!doctype html>")
               (data (i32.const 271) "text/html")
               (func $doctype (export "doctype") (result i32)
                 (i32.const 255)
               )
               (func $mime_type (export "mime_type") (result i32)
                 (i32.const 271)
               )
             )
             """
    end
  end

  defmodule SingleFunc do
    use Orb

    wasm do
      func answer(), I32 do
        42
      end
    end
  end

  test "wasm/1 defines __wasm_module__/0" do
    alias Orb

    wasm = SingleFunc.__wasm_module__()

    assert wasm == %Orb.ModuleDefinition{
             name: "SingleFunc",
             body: [
               %Orb.Func{
                 name: :answer,
                 params: [],
                 result: {:result, :i32},
                 local_types: [],
                 body: [42],
                 exported?: true
               }
             ]
           }
  end

  test "to_wat/1 wasm" do
    wasm_source = """
    (module $SingleFunc
      (func $answer (export "answer") (result i32)
        (i32.const 42)
      )
    )
    """

    assert to_wat(SingleFunc) == wasm_source
  end

  defmodule ManyFuncs do
    use Orb

    wasm do
      func answer(), I32 do
        I32.mul(2, 21)
      end

      func get_pi(), :f32 do
        3.14
      end

      funcp internal(), :f32 do
        99.0
      end
    end
  end

  test "to_wat/1 wasm many funcs" do
    wasm_source = """
    (module $ManyFuncs
      (func $answer (export "answer") (result i32)
        (i32.mul (i32.const 2) (i32.const 21))
      )
      (func $get_pi (export "get_pi") (result f32)
        (f32.const 3.14)
      )
      (func $internal (result f32)
        (f32.const 99.0)
      )
    )
    """

    assert to_wat(ManyFuncs) == wasm_source
  end

  defmodule HTTPStatusLookup do
    use Orb

    @statuses [
      {200, "OK"},
      {201, "Created"},
      {204, "No Content"},
      {205, "Reset Content"},
      {301, "Moved Permanently"},
      {302, "Found"},
      {303, "See Other"},
      {304, "Not Modified"},
      {307, "Temporary Redirect"},
      {400, "Bad Request"},
      {401, "Unauthorized"},
      {403, "Forbidden"},
      {404, "Not Found"},
      {405, "Method Not Allowed"},
      {409, "Conflict"},
      {412, "Precondition Failed"},
      {413, "Payload Too Large"},
      {422, "Unprocessable Entity"},
      {429, "Too Many Requests"}
    ]

    def status_table(), do: @statuses

    Memory.pages(1)

    wasm do
      inline for {status, message} <- ^@statuses do
        # data(status * 24, "#{message}\\00")
        # data(status * 24, message)
        data_nul_terminated(status * 24, message)
      end

      func lookup(status: I32), I32 do
        I32.mul(status, 24)
      end
    end
  end

  # FIXME: this shouldn’t live in orb_test.exs
  test "works" do
    alias OrbWasmtime.Instance

    inst = Instance.run(HTTPStatusLookup)
    assert Instance.call_reading_string(inst, :lookup, 200) == "OK"

    for {status, status_text} <- HTTPStatusLookup.status_table() do
      assert Instance.call_reading_string(inst, :lookup, status) == status_text
    end
  end

  test "to_wat/1 many data" do
    wasm_source = ~s"""
    (module $HTTPStatusLookup
      (memory (export "memory") 1)
      (data (i32.const #{200 * 24}) "OK\\00")
      (data (i32.const #{201 * 24}) "Created\\00")
      (data (i32.const #{204 * 24}) "No Content\\00")
      (data (i32.const #{205 * 24}) "Reset Content\\00")
      (data (i32.const #{301 * 24}) "Moved Permanently\\00")
      (data (i32.const #{302 * 24}) "Found\\00")
      (data (i32.const #{303 * 24}) "See Other\\00")
      (data (i32.const #{304 * 24}) "Not Modified\\00")
      (data (i32.const #{307 * 24}) "Temporary Redirect\\00")
      (data (i32.const #{400 * 24}) "Bad Request\\00")
      (data (i32.const #{401 * 24}) "Unauthorized\\00")
      (data (i32.const #{403 * 24}) "Forbidden\\00")
      (data (i32.const #{404 * 24}) "Not Found\\00")
      (data (i32.const #{405 * 24}) "Method Not Allowed\\00")
      (data (i32.const #{409 * 24}) "Conflict\\00")
      (data (i32.const #{412 * 24}) "Precondition Failed\\00")
      (data (i32.const #{413 * 24}) "Payload Too Large\\00")
      (data (i32.const #{422 * 24}) "Unprocessable Entity\\00")
      (data (i32.const #{429 * 24}) "Too Many Requests\\00")
      (func $lookup (export "lookup") (param $status i32) (result i32)
        (i32.mul (local.get $status) (i32.const 24))
      )
    )
    """

    assert to_wat(HTTPStatusLookup) == wasm_source
  end

  defmodule WithinRange do
    use Orb

    wasm do
      func validate(num: I32), I32, under?: I32, over?: I32 do
        under? = I32.lt_s(num, 1)
        over? = I32.gt_s(num, 255)

        I32.or(under?, over?) |> I32.eqz()
      end
    end
  end

  test "checking a number is within a range" do
    alias OrbWasmtime.Wasm

    wasm_source = """
    (module $WithinRange
      (func $validate (export "validate") (param $num i32) (result i32)
        (local $under? i32)
        (local $over? i32)
        (i32.lt_s (local.get $num) (i32.const 1))
        (local.set $under?)
        (i32.gt_s (local.get $num) (i32.const 255))
        (local.set $over?)
        (i32.eqz (i32.or (local.get $under?) (local.get $over?)))
      )
    )
    """

    assert to_wat(WithinRange) == wasm_source
    assert Wasm.call(WithinRange, "validate", 0) == 0
    assert Wasm.call(WithinRange, "validate", 1) == 1
    assert Wasm.call(WithinRange, "validate", 100) == 1
    assert Wasm.call(WithinRange, "validate", 255) == 1
    assert Wasm.call(WithinRange, "validate", 256) == 0
  end

  defmodule CalculateMean do
    use Orb

    I32.global(
      count: 0,
      tally: 0
    )

    wasm do
      func insert(element: I32) do
        @count = @count + 1
        @tally = @tally + element
      end

      func calculate_mean(), I32 do
        @tally / @count
      end

      func calculate_mean_and_count(), {I32, I32} do
        @tally / @count
        @count
      end
    end
  end

  test "CalculateMean to_wat" do
    wasm_source = """
    (module $CalculateMean
      (global $count (mut i32) (i32.const 0))
      (global $tally (mut i32) (i32.const 0))
      (func $insert (export "insert") (param $element i32)
        (i32.add (global.get $count) (i32.const 1))
        (global.set $count)
        (i32.add (global.get $tally) (local.get $element))
        (global.set $tally)
      )
      (func $calculate_mean (export "calculate_mean") (result i32)
        (i32.div_s (global.get $tally) (global.get $count))
      )
      (func $calculate_mean_and_count (export "calculate_mean_and_count") (result i32 i32)
        (i32.div_s (global.get $tally) (global.get $count))
        (global.get $count)
      )
    )
    """

    assert Orb.to_wat(CalculateMean) == wasm_source
  end

  test "CalculateMean works" do
    alias OrbWasmtime.Instance

    inst = Instance.run(CalculateMean)
    Instance.call(inst, :insert, 4)
    Instance.call(inst, :insert, 5)
    Instance.call(inst, :insert, 6)
    assert Instance.call(inst, :calculate_mean) == 5
    assert Instance.call(inst, :calculate_mean_and_count) == {5, 3}
  end

  defmodule FileNameSafe do
    use Orb

    Memory.pages(2)

    wasm do
      func get_is_valid(), I32, str: I32.U8.Pointer, char: I32 do
        str = 1024

        loop :continue, result: I32 do
          defblock Outer do
            defblock :inner do
              char = str[at!: 0]
              break(:inner, if: I32.eq(char, ?/))
              break(Outer, if: char)
              return(1)
            end

            return(0)
          end

          str = str + 1
          {:br, :continue}
        end
      end
    end
  end

  test "loop" do
    wasm_source = """
    (module $FileNameSafe
      (memory (export "memory") 2)
      (func $get_is_valid (export "get_is_valid") (result i32)
        (local $str i32)
        (local $char i32)
        (i32.const 1024)
        (local.set $str)
        (loop $continue (result i32)
          (block $Outer
            (block $inner
              (i32.load8_u (local.get $str))
              (local.set $char)
              (i32.eq (local.get $char) (i32.const 47))
              br_if $inner
              (local.get $char)
              br_if $Outer
              (return (i32.const 1))
            )
            (return (i32.const 0))
          )
          (i32.add (local.get $str) (i32.const 1))
          (local.set $str)
          br $continue
        )
      )
    )
    """

    assert to_wat(FileNameSafe) == wasm_source
    # assert Wasm.call(FileNameSafe, "body") == 100
  end
end
