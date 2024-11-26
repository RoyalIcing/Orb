defmodule OrbTest do
  use ExUnit.Case, async: true

  import Orb, only: [to_wat: 1]

  test "basic module" do
    import Orb.DSL

    defmodule Basic do
      use Orb

      defw answer(), I32 do
        42
      end
    end

    wasm_source = """
    (module $Basic
      (func $answer (export "answer") (result i32)
        (i32.const 42)
      )
    )
    """

    assert to_wat(Basic) == wasm_source
  end

  test "multiple return values" do
    import Orb.DSL

    defmodule MultipleReturn do
      use Orb

      defw answers(b: I32), {I32, I32}, a: I32 do
        a = 99 + b

        {42, a}
      end

      defw xyz(), {F32, F32, F32} do
        {1.0, 2.0, 3.0}
      end
    end

    assert ~S"""
           (module $MultipleReturn
             (func $answers (export "answers") (param $b i32) (result i32 i32)
               (local $a i32)
               (i32.add (i32.const 99) (local.get $b))
               (local.set $a)
               (i32.const 42)
               (local.get $a)
             )
             (func $xyz (export "xyz") (result f32 f32 f32)
               (f32.const 1.0)
               (f32.const 2.0)
               (f32.const 3.0)
             )
           )
           """ = to_wat(MultipleReturn)
  end

  test "assigning and returning tuples" do
    defmodule VarInt do
      use Orb

      defw parse_varint(ptr: I32.UnsafePointer), {I32, I32},
        int: I32,
        size: I32,
        new_int: I32,
        high_bit: I32 do
        loop offset <- 0..8 do
          new_int = Memory.load!(I32.U8, ptr + offset)
          high_bit = new_int &&& 0b1000_0000
          new_int = new_int &&& 0b0111_1111
          # <<high_bit::1, new_int::7>> = Memory.load!(I32.U8, ptr + 0)

          if size === 8 do
            return(%Orb.InstructionSequence{body: [{(int <<< 8) + new_int, size + 1}]})
          end

          if high_bit === 0 do
            return(%Orb.InstructionSequence{body: [{(int <<< 7) + new_int, size + 1}]})
          end

          int = (int <<< 7) + new_int
          size = size + 1
        end

        {int, size}
      end

      defw read_cell(ptr: I32.UnsafePointer, len: I32), {I32, I32},
        payload_size: I32,
        var_size: I32 do
        {payload_size, var_size} = parse_varint(ptr)

        {payload_size, var_size}
      end
    end

    assert ~S"""
           (module $VarInt
             (func $parse_varint (export "parse_varint") (param $ptr i32) (result i32 i32)
               (local $int i32)
               (local $size i32)
               (local $new_int i32)
               (local $high_bit i32)
               (local $offset i32)
               (i32.const 0)
               (local.set $offset)
               (loop $offset
                 (i32.load8_u (i32.add (local.get $ptr) (local.get $offset)))
                 (local.set $new_int)
                 (i32.and (local.get $new_int) (i32.const 128))
                 (local.set $high_bit)
                 (i32.and (local.get $new_int) (i32.const 127))
                 (local.set $new_int)
                 (i32.eq (local.get $size) (i32.const 8))
                 (if
                   (then
                     (return (i32.add (i32.shl (local.get $int) (i32.const 8)) (local.get $new_int))
           (i32.add (local.get $size) (i32.const 1))
           )
                   )
                 )
                 (i32.eq (local.get $high_bit) (i32.const 0))
                 (if
                   (then
                     (return (i32.add (i32.shl (local.get $int) (i32.const 7)) (local.get $new_int))
           (i32.add (local.get $size) (i32.const 1))
           )
                   )
                 )
                 (i32.add (i32.shl (local.get $int) (i32.const 7)) (local.get $new_int))
                 (local.set $int)
                 (i32.add (local.get $size) (i32.const 1))
                 (local.set $size)
                 (i32.add (local.get $offset) (i32.const 1))
                 (local.set $offset)
                 (i32.le_u (local.get $offset) (i32.const 8))
                 (br_if $offset)
               )
               (local.get $int)
               (local.get $size)
             )
             (func $read_cell (export "read_cell") (param $ptr i32) (param $len i32) (result i32 i32)
               (local $payload_size i32)
               (local $var_size i32)
               (call $parse_varint (local.get $ptr))
               (local.set $payload_size)
               (local.set $var_size)
               (local.get $payload_size)
               (local.get $var_size)
             )
           )
           """ = to_wat(VarInt)
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

    test "3 x Memory.pages/1 sums each value" do
      defmodule TwicePages2 do
        use Orb

        Memory.pages(2)
        Memory.pages(3)
        Memory.pages(1)
      end

      assert to_wat(TwicePages2) == """
             (module $TwicePages2
               (memory (export "memory") 6)
             )
             """
    end

    test "reading and writing" do
      defmodule MemoryLoadStore do
        use Orb

        Memory.pages(1)

        defw get_int32(), I32 do
          Memory.load!(I32, 0x100)
        end

        defw set_int32(value: I32) do
          Memory.store!(I32, 0x100, value)
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

  defmodule SingleFunc do
    use Orb

    defw answer(), I32 do
      42
    end
  end

  test "wasm/1 defines __wasm_module__/0" do
    alias Orb

    wasm = SingleFunc.__wasm_module__()

    assert wasm === %Orb.ModuleDefinition{
             name: "SingleFunc",
             body: [
               %Orb.Func{
                 name: :answer,
                 params: [],
                 result: Orb.I32,
                 local_types: [],
                 body: %Orb.InstructionSequence{
                   push_type: Orb.I32,
                   body: [
                     %Orb.Instruction{push_type: :i32, operation: :const, operands: [42]}
                   ]
                 },
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

  defmodule CallSiblingFunc do
    use Orb

    defwp forty_two(), I32 do
      42
    end

    defwp forty_two_plus(n: I32), I32 do
      42 + n
    end

    defw meaning_of_life(), I32 do
      if i32(1), result: I32 do
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

      for {status, message} <- @statuses do
        Memory.initial_data!(status * 24, message)
      end

      defw lookup(status: I32), I32 do
        status * 24
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

  test "tuple types" do
    defmodule TupleTypes do
      use Orb

      defw rgb_reverse(r: F32, g: F32, b: F32), {F32, F32, F32} do
        b
        g
        r
      end

      defw rgb_average(r: F32, g: F32, b: F32), F32 do
        (b + g + r) / 3.0
      end

      defw main do
        rgb_reverse(1.0, 0.5, 0.0) |> Orb.Stack.drop()
      end
    end

    alias OrbWasmtime.Wasm
    assert {0.0, 0.5, 1.0} === Wasm.call(TupleTypes, :rgb_reverse, 1.0, 0.5, 0.0)
  end

  test "range-bounded params" do
    defmodule RangeBounded do
      use Orb

      # @orb_experimental %{range_params: true}

      # defw two_to_five(a: 2.0 < F32 < 5.0), I32 do
      # defw two_to_five(a: 2 <= I32 <= 5), I32 do

      defw declare_defcon(a: 1..5), I32 do
        # guard when a >= 1 and a <= 5, else: unreachable()
        # unreachable! unless a >= 1 and a <= 5
        # assert!(a >= 1 &&& a <= 5)
        # assert!(a in 1..5)
        # assert! do
        #   a in 1..5
        #   b in 1..5
        # end
        a
      end
    end

    wat = RangeBounded.to_wat()
    assert wat =~ "unreachable"
    assert wat =~ "(i32.ge_s (local.get $a) (i32.const 1))"
    assert wat =~ "(i32.le_s (local.get $a) (i32.const 5))"

    alias OrbWasmtime.Wasm
    assert 1 = Wasm.call(wat, :declare_defcon, 1)
    assert 2 = Wasm.call(wat, :declare_defcon, 2)
    assert 3 = Wasm.call(wat, :declare_defcon, 3)
    assert 4 = Wasm.call(wat, :declare_defcon, 4)
    assert 5 = Wasm.call(wat, :declare_defcon, 5)
    assert {:error, _} = Wasm.call(wat, :declare_defcon, 0)
    assert {:error, _} = Wasm.call(wat, :declare_defcon, 6)
    assert {:error, _} = Wasm.call(wat, :declare_defcon, 10)
  end

  test "Orb.include/1 copies all functions" do
    defmodule MathUtils do
      use Orb

      defw(square(n: I32), I32, do: n * n)
    end

    defmodule Includer do
      use Orb

      Orb.include(MathUtils)

      defw magic(), I32 do
        MathUtils.square(3)
      end
    end

    alias OrbWasmtime.Wasm
    assert 9 = Wasm.call(Includer, :magic)
    assert [{:func, "magic"}] = Wasm.list_exports(Includer)
  end

  test "snippet works" do
    defmodule SnippetDefiner do
      def hd!(ptr) do
        alias Orb.{I32, U32, Memory}

        Orb.snippet U32 do
          Memory.load!(I32, ptr + 4)
        end
      end
    end

    defmodule SnippetUser do
      use Orb

      Memory.pages(1)

      defw answer(), I32 do
        SnippetDefiner.hd!(0x100)
      end
    end

    wasm_source = """
    (module $SnippetUser
      (memory (export "memory") 1)
      (func $answer (export "answer") (result i32)
        (i32.load (i32.const #{0x104}))
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
      @behaviour Orb.CustomType
      @behaviour Orb.Table.Type

      @impl Orb.CustomType
      def wasm_type, do: %Orb.Func.Type{result: I32}

      @impl Orb.CustomType
      def type_name, do: :answer

      @impl Orb.Table.Type
      def table_func_keys, do: [:good, :bad]

      def call(elem_index) do
        Table.call_indirect(wasm_type(), type_name(), elem_index)
      end
    end

    defmodule Other do
      @behaviour Orb.CustomType
      @behaviour Orb.Table.Type

      @impl Orb.CustomType
      def wasm_type, do: %Orb.Func.Type{result: I32}

      @impl Orb.CustomType
      def type_name, do: :other

      @impl Orb.Table.Type
      def table_func_keys, do: [:foo, :goo]

      def call(elem_index) do
        Table.call_indirect(wasm_type(), type_name(), elem_index)
      end
    end

    types([Answer, Other])
    Table.allocate(Answer)
    Table.allocate(Other)

    # global do
    #   i32 state(4), counter(0)
    #   @state 4
    #   @counter 0
    #   f32 t(0.0)
    # end

    @table {Answer, :good}
    defw good_answer(), I32 do
      42
    end

    @table {Answer, :bad}
    @table {Other, :foo}
    defw bad_answer(), I32 do
      13
    end

    defw answer(), {I32, I32, I32} do
      {
        Answer.call(Table.lookup!(Answer, :good)),
        Answer.call(Table.lookup!(Answer, :bad)),
        Answer.call(Table.lookup!(Other, :foo))
      }
    end
  end

  test "table elem" do
    alias OrbWasmtime.Wasm

    assert """
           (module $TableExample
             (type $answer (func (result i32)))
             (type $other (func (result i32)))
             (table 4 funcref)
             (func $good_answer (export "good_answer") (result i32)
               (i32.const 42)
             )
             (elem (i32.const 0) $good_answer)
             (func $bad_answer (export "bad_answer") (result i32)
               (i32.const 13)
             )
             (elem (i32.const 1) $bad_answer)
             (elem (i32.const 2) $bad_answer)
             (func $answer (export "answer") (result i32 i32 i32)
               (call_indirect (type $answer) (i32.const 0))
               (call_indirect (type $answer) (i32.const 1))
               (call_indirect (type $answer) (i32.const 2))
             )
           )
           """ = to_wat(TableExample)

    assert Wasm.call(TableExample, :answer) === {42, 13, 13}
  end

  test "compiler errors reset state" do
    # https://github.com/RoyalIcing/Orb/issues/18
    defmodule ExampleWithError do
      use Orb

      defw fahrenheit_to_celsius(fahrenheit: F32), F32 do
        raise CompileError, description: "error"
      end
    end

    assert_raise(CompileError, fn -> Orb.to_wat(ExampleWithError) end)
    assert_raise(CompileError, fn -> Orb.to_wat(ExampleWithError) end)
  end
end
