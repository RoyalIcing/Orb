defmodule OrbTest do
  use ExUnit.Case, async: true

  use Orb

  test "func" do
    import Orb.DSL

    wasm =
      func answer(), I32 do
        42
      end

    wasm_source = """
    (func $answer (export "answer") (result i32)
      (i32.const 42)
    )
    """

    assert to_wat(wasm) == wasm_source
  end

  test "funcp" do
    import Orb.DSL

    wasm =
      funcp answer(), I32 do
        42
      end

    wasm_source = """
    (func $answer (result i32)
      (i32.const 42)
    )
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

    test "global do" do
      defmodule GlobalDo do
        use Orb

        global do
          @abc 42
        end

        global :readonly do
          @const 99
        end

        global :export_mutable do
          @public1 11
        end

        global :export_readonly do
          @public2 22
        end

        global :readonly do
          @five_quarters 1.25
        end

        def all_attributes do
          [@abc, @const, @public1, @public2, @five_quarters]
        end
      end

      assert to_wat(GlobalDo) == """
             (module $GlobalDo
               (global $abc (mut i32) (i32.const 42))
               (global $const i32 (i32.const 99))
               (global $public1 (export "public1") (mut i32) (i32.const 11))
               (global $public2 (export "public2") i32 (i32.const 22))
               (global $five_quarters f32 (f32.const 1.25))
             )
             """

      assert GlobalDo.all_attributes() == [42, 99, 11, 22, 1.25]
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

    test "F32" do
      defmodule GlobalsF32 do
        use Orb

        F32.global(abc: 42.0)
        F32.global(:readonly, BAD_PI: 3.14)
        F32.export_global(:mutable, public1: 11.0)
        F32.export_global(:readonly, public2: 22.0)
      end

      assert to_wat(GlobalsF32) == """
             (module $GlobalsF32
               (global $abc (mut f32) (f32.const 42.0))
               (global $BAD_PI f32 (f32.const 3.14))
               (global $public1 (export "public1") (mut f32) (f32.const 11.0))
               (global $public2 (export "public2") f32 (f32.const 22.0))
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

    test "reading and writing" do
      defmodule MemoryLoadStore do
        use Orb

        Memory.pages(1)

        wasm do
          func get_int32(), I32 do
            Memory.load!(I32, 0x100)
          end

          func set_int32(value: I32) do
            Memory.store!(I32, 0x100, value)
          end
        end
      end

      assert to_wat(MemoryLoadStore) == """
             (module $MemoryLoadStore
               (memory (export "memory") 1)
               (func $get_int32 (export "get_int32") (result i32)
                 (i32.load (i32.const 256))
               )
               (func $set_int32 (export "set_int32") (param $value i32)
                 (i32.store (i32.const 256) (local.get $value))
               )
             )
             """
    end
  end

  describe "imports" do
    test "can declare import" do
      defmodule ImportsLog32 do
        use Orb
        import Orb.DSL, only: [funcp: 1]

        # Import.funcp(:log, :int32, as: :log_i32, params: I32, result: I32)
        # wasm_import(:log,
        #   int32: funcp(log_i32(_: I32), I32)
        # )

        wasm_import(:echo,
          int32: funcp(name: :echo_i32, params: I32, result: I32),
          int64: funcp(name: :echo_i64, params: I64, result: I64)
        )

        wasm_import(:log,
          int32: funcp(name: :log_i32, params: I32),
          int64: funcp(name: :log_i64, params: I64)
        )

        wasm_import(:time,
          seconds_since_unix_epoch: funcp(name: :unix_time, result: I64)
        )
      end

      assert to_wat(ImportsLog32) == """
             (module $ImportsLog32
               (import "echo" "int32" (func $echo_i32 (param i32) (result i32)))
               (import "echo" "int64" (func $echo_i64 (param i64) (result i64)))
               (import "log" "int32" (func $log_i32 (param i32)))
               (import "log" "int64" (func $log_i64 (param i64)))
               (import "time" "seconds_since_unix_epoch" (func $unix_time (result i64)))
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

    test "works with multiple wasm blocks" do
      defmodule HTMLTypes2 do
        use Orb

        wasm do
          func doctype(), I32 do
            ~S"<!doctype html>"
          end
        end

        wasm do
          func mime_type(), I32 do
            ~S"text/html"
          end
        end
      end

      assert to_wat(HTMLTypes2) == """
             (module $HTMLTypes2
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

  describe "const/1" do
    test "assigns data" do
      defmodule ConstHTMLTypes do
        use Orb

        wasm do
          func doctype(), I32 do
            const("<!doctype html>")
          end

          func mime_type(), I32 do
            const(Enum.join(["text", "/", "html"]))
          end
        end
      end

      assert to_wat(ConstHTMLTypes) == """
             (module $ConstHTMLTypes
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

    test "works with multiple wasm blocks" do
      defmodule ConstHTMLTypes2 do
        use Orb

        wasm do
          func doctype(), I32 do
            const(Enum.join(["<!doctype ", "html>"]))
          end
        end

        wasm do
          func mime_type(), I32 do
            const(Enum.join(["text", "/", "html"]))
          end
        end
      end

      assert to_wat(ConstHTMLTypes2) == """
             (module $ConstHTMLTypes2
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
                 result: Orb.I32,
                 local_types: [],
                 body: [42],
                 exported_names: ["answer"]
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
      |> export("get_pi_a")

      funcp internal(), :f32 do
        99.0
      end

      funcp secret(), :f32 do
        42.0
      end
      |> export("exposed_secret")
      |> export("tell_everyone")
    end
  end

  test "to_wat/1 wasm many funcs" do
    wasm_source = """
    (module $ManyFuncs
      (func $answer (export "answer") (result i32)
        (i32.mul (i32.const 2) (i32.const 21))
      )
      (func $get_pi (export "get_pi") (export "get_pi_a") (result f32)
        (f32.const 3.14)
      )
      (func $internal (result f32)
        (f32.const 99.0)
      )
      (func $secret (export "exposed_secret") (export "tell_everyone") (result f32)
        (f32.const 42.0)
      )
    )
    """

    assert to_wat(ManyFuncs) == wasm_source
  end

  defmodule CallSiblingFunc do
    use Orb

    defwp forty_two(), I32 do
      42
    end

    defwp forty_two_plus(n: I32), I32 do
      42 + n
    end

    defw meaning_of_life(), I32 do
      if 1, result: I32 do
        forty_two_plus(9)
      else
        forty_two()
      end
    end
  end

  test "using func does def for you" do
    wasm_source = """
    (module $CallSiblingFunc
      (func $forty_two (result i32)
        (i32.const 42)
      )
      (func $forty_two_plus (param $n i32) (result i32)
        (i32.add (i32.const 42) (local.get $n))
      )
      (func $meaning_of_life (export "meaning_of_life") (result i32)
        (i32.const 1)
        (if (result i32)
          (then
            (call $forty_two_plus (i32.const 9))
          )
          (else
            (call $forty_two)
          )
        )
      )
    )
    """

    assert to_wat(CallSiblingFunc) === wasm_source
  end

  describe "data lookup" do
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
        # inline do
        #   for {status, message} <- @statuses do
        #     Memory.initial_data(offset: status * 24, string: message)
        #   end
        # end
        inline for {status, message} <- @statuses do
          Memory.initial_data(offset: status * 24, string: message)
        end

        # inline for {status, message} <- status_table() do
        #   Memory.initial_data(offset: status * 24, string: message)
        # end

        func lookup(status: I32), I32 do
          status * 24
        end
      end
    end

    # TODO: should this live here?
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
        (data (i32.const #{200 * 24}) "OK")
        (data (i32.const #{201 * 24}) "Created")
        (data (i32.const #{204 * 24}) "No Content")
        (data (i32.const #{205 * 24}) "Reset Content")
        (data (i32.const #{301 * 24}) "Moved Permanently")
        (data (i32.const #{302 * 24}) "Found")
        (data (i32.const #{303 * 24}) "See Other")
        (data (i32.const #{304 * 24}) "Not Modified")
        (data (i32.const #{307 * 24}) "Temporary Redirect")
        (data (i32.const #{400 * 24}) "Bad Request")
        (data (i32.const #{401 * 24}) "Unauthorized")
        (data (i32.const #{403 * 24}) "Forbidden")
        (data (i32.const #{404 * 24}) "Not Found")
        (data (i32.const #{405 * 24}) "Method Not Allowed")
        (data (i32.const #{409 * 24}) "Conflict")
        (data (i32.const #{412 * 24}) "Precondition Failed")
        (data (i32.const #{413 * 24}) "Payload Too Large")
        (data (i32.const #{422 * 24}) "Unprocessable Entity")
        (data (i32.const #{429 * 24}) "Too Many Requests")
        (func $lookup (export "lookup") (param $status i32) (result i32)
          (i32.mul (local.get $status) (i32.const 24))
        )
      )
      """

      assert to_wat(HTTPStatusLookup) == wasm_source
    end
  end

  defmodule WithinRange do
    use Orb

    defw validate(num: I32), I32, under?: I32, over?: I32 do
      under? = num < 1
      over? = num > 255

      not (under? or over?)
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

    defw insert(element: I32) do
      @count = @count + 1
      @tally = @tally + element
    end

    # defw calculate_mean() :: I32 do
    defw calculate_mean(), I32 do
      @tally / @count
    end

    defw calculate_mean_and_count(), {I32, I32} do
      @tally / @count
      @count
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
      func get_is_valid(), I32, str: I32.U8.UnsafePointer, char: I32 do
        str = 1024

        loop Loop, result: I32 do
          Control.block Outer do
            Control.block :inner do
              char = str[at!: 0]
              Control.break(:inner, if: I32.eq(char, ?/))
              Outer.break(if: char)
              return(1)
            end

            return(0)
          end

          str = str + 1
          Loop.continue()
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
        (loop $Loop (result i32)
          (block $Outer
            (block $inner
              (i32.load8_u (local.get $str))
              (local.set $char)
              (i32.eq (local.get $char) (i32.const 47))
              (br_if $inner)
              (local.get $char)
              (br_if $Outer)
              (return (i32.const 1))
            )
            (return (i32.const 0))
          )
          (i32.add (local.get $str) (i32.const 1))
          (local.set $str)
          (br $Loop)
        )
      )
    )
    """

    assert to_wat(FileNameSafe) == wasm_source
    # assert Wasm.call(FileNameSafe, "body") == 100
  end

  defmodule SnippetDefiner do
    def hd!(ptr) do
      Orb.snippet U32 do
        Memory.load!(I32, ptr + 4)
      end
    end
  end

  defmodule SnippetUser do
    use Orb

    Memory.pages(1)

    wasm do
      func answer(), I32 do
        SnippetDefiner.hd!(0x100)
      end
    end
  end

  test "snippet works" do
    wasm_source = """
    (module $SnippetUser
      (memory (export "memory") 1)
      (func $answer (export "answer") (result i32)
        (i32.load (i32.add (i32.const #{0x100}) (i32.const 4)))
      )
    )
    """

    assert to_wat(SnippetUser) == wasm_source
  end

  defmodule TableExample do
    use Orb

    # a = make_ref()
    # b = make_ref()

    # @a make_ref()

    # defmodule Table do
    #   require Orb.DSL
    #   functype answer(), I32
    #   def good_answer, do: :answer
    #   def bad_answer, do: :answer

    #   use Orb.Table

    #   functype good_answer(), I32
    #   functype bad_answer(), I32
    # end

    # wasm_table do
    #   functype good_answer(), I32
    #   functype bad_answer(), I32
    # end

    # good_answer = table_func(), I32

    # table_func good_answer(), I32

    # functype answer(), I32
    # good_answer = table_func(answer)
    # bad_answer = table_func(answer)

    # @good_answer table_func(answer)
    # @bad_answer table_func(answer)

    # table(
    #   good_answer: answer,
    #   bad_answer: answer,
    # )

    # functype answer(), I32, elems: [:good_answer, :bad_answer]

    # defmodule Answer do
    #   use Orb.Table

    #   functype(_(), I32)

    #   elem :good_answer
    #   elem :bad_answer
    # end

    # types do
    #   func(answer(), I32)
    # end
    # functype(answer(), I32)

    # use Table(
    # Table.allocate(
    #   good_answer: :answer,
    #   bad_answer: :answer
    # )

    defmodule Answer do
      # use Orb.Type, :answer, %Orb.Func.Type{result: I32}
      # use Orb.TableEntries, result: I32

      def type_name, do: :answer
      def wasm_type, do: %Orb.Func.Type{result: I32}
      def table_func_keys(), do: [:good, :bad]

      def call(elem_index) do
        Table.call_indirect(type_name(), elem_index)
      end
    end

    types([Answer])
    Table.allocate(Answer)

    # global do
    #   i32 state(4), counter(0)
    #   @state 4
    #   @counter 0
    #   f32 t(0.0)
    # end

    wasm do
      func good_answer(), I32 do
        42
      end
      |> Table.elem!(Answer, :good)

      func bad_answer(), I32 do
        13
      end
      |> Table.elem!(Answer, :bad)

      func answer(), I32 do
        Answer.call(Table.lookup!(Answer, :good))
      end
    end
  end

  test "table elem" do
    alias OrbWasmtime.Wasm

    wasm_source = """
    (module $TableExample
      (type $answer (func (result i32)))
      (table 2 funcref)
      (func $good_answer (export "good_answer") (result i32)
        (i32.const 42)
      )
      (elem (i32.const 0) $good_answer)
      (func $bad_answer (export "bad_answer") (result i32)
        (i32.const 13)
      )
      (elem (i32.const 1) $bad_answer)
      (func $answer (export "answer") (result i32)
        (call_indirect (type $answer) (i32.const 0))
      )
    )
    """

    assert to_wat(TableExample) == wasm_source

    assert Wasm.call(TableExample, :answer) === 42
  end
end
