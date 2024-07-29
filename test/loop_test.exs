defmodule LoopTest do
  use ExUnit.Case, async: true
  require TestHelper
  alias OrbWasmtime.Wasm

  test "block stack" do
    require TestHelper

    assert (TestHelper.module_wat do
              use Orb

              defw example(a: I32), b: I32 do
                Control.block Outer do
                  Orb.Stack.push(a)

                  Control.block Inner do
                  end

                  # mut!(b).read_stack
                  # Orb.Stack.pop(mut!(b))
                  b = Orb.Stack.pop(I32)
                end
              end
            end) =~ ~s"""
               (block $Outer
                 (local.get $a)
                 (block $Inner
                 )
                 (local.set $b)
               )
           """
  end

  test "loop through chars manually" do
    defmodule FileNameSafe do
      use Orb

      Memory.pages(2)

      defw get_is_valid(), I32, str: I32.U8.UnsafePointer, char: I32 do
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

    assert """
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
           """ === Orb.to_wat(FileNameSafe)
  end

  test "loop 1..10" do
    defmodule Loop1To10 do
      use Orb

      defw sum1to10(), I32, sum: I32 do
        # let(I32, sum: 0)
        # sum = 0
        # let sum: i32(0)
        # i32 sum: 0
        # let sum <- I32 do
        # let sum(I32) do
        # I32.def sum: 0
        # local sum: I32
        # sum :: I32 = 0
        # f32(r: 0.0)

        loop i <- 1..10 do
          sum = sum + i
        end

        sum

        # let sum: I32, mean: I32 do
        #   loop i <- 1..10 do
        #     sum = sum + i
        #   end

        #   sum
        # end
      end
    end

    wat = """
    (module $Loop1To10
      (func $sum1to10 (export "sum1to10") (result i32)
        (local $sum i32)
        (local $i i32)
        (i32.const 1)
        (local.set $i)
        (loop $i
          (i32.add (local.get $sum) (local.get $i))
          (local.set $sum)
          (i32.add (local.get $i) (i32.const 1))
          (local.set $i)
          (i32.le_u (local.get $i) (i32.const 10))
          (br_if $i)
        )
        (local.get $sum)
      )
    )
    """

    assert wat == Orb.to_wat(Loop1To10)
    assert 55 = Wasm.call(Loop1To10, :sum1to10)
  end

  describe "iterators" do
    defmodule AlphabetIterator do
      def new(), do: ?a

      with @behaviour b = Orb.CustomType do
        @impl b
        defdelegate wasm_type, to: Orb.I32
      end

      with @behaviour b = Orb.Iterator do
        @impl b
        def valid?(var), do: Orb.I32.le_u(var, ?z)
        @impl b
        def value(var), do: var
        @impl b
        def next(var), do: Orb.I32.add(var, 1)
      end
    end

    defmodule IteratorConsumer do
      use Orb

      defw test, I32, i: I32, alpha: AlphabetIterator do
        alpha = AlphabetIterator.new()

        loop char <- alpha do
          i = i + 1
        end

        i
      end

      defw test2, I32, i: I32, alpha: AlphabetIterator do
        alpha = AlphabetIterator.new()

        loop _ <- alpha do
          i = i + 1
        end

        i
      end

      defw test3, I32, i: I32, alpha: AlphabetIterator do
        alpha = AlphabetIterator.new()

        loop char <- alpha do
          i = i + char
        end

        i
      end
    end

    test "behaves correctly" do
      assert 26 = Wasm.call(IteratorConsumer, :test)
      assert 26 = Wasm.call(IteratorConsumer, :test2)
      assert 2847 = Wasm.call(IteratorConsumer, :test3)
      assert 2847 = Enum.sum(?a..?z)
    end

    test "compiles correctly" do
      assert """
             (module $IteratorConsumer
               (func $test (export "test") (result i32)
                 (local $i i32)
                 (local $alpha i32)
                 (local $char i32)
                 (i32.const 97)
                 (local.set $alpha)
                 (loop $char
                   (i32.le_u (local.get $alpha) (i32.const 122))
                   (if
                     (then
                       (local.get $alpha)
                       (local.set $char)
                       (i32.add (local.get $i) (i32.const 1))
                       (local.set $i)
                       (i32.add (local.get $alpha) (i32.const 1))
                       (local.set $alpha)
                       (br $char)
                     )
                   )    )
                 (local.get $i)
               )
               (func $test2 (export "test2") (result i32)
                 (local $i i32)
                 (local $alpha i32)
                 (i32.const 97)
                 (local.set $alpha)
                 (loop $_
                   (i32.le_u (local.get $alpha) (i32.const 122))
                   (if
                     (then
                       (i32.add (local.get $i) (i32.const 1))
                       (local.set $i)
                       (i32.add (local.get $alpha) (i32.const 1))
                       (local.set $alpha)
                       (br $_)
                     )
                   )    )
                 (local.get $i)
               )
               (func $test3 (export "test3") (result i32)
                 (local $i i32)
                 (local $alpha i32)
                 (local $char i32)
                 (i32.const 97)
                 (local.set $alpha)
                 (loop $char
                   (i32.le_u (local.get $alpha) (i32.const 122))
                   (if
                     (then
                       (local.get $alpha)
                       (local.set $char)
                       (i32.add (local.get $i) (local.get $char))
                       (local.set $i)
                       (i32.add (local.get $alpha) (i32.const 1))
                       (local.set $alpha)
                       (br $char)
                     )
                   )    )
                 (local.get $i)
               )
             )
             """ = Orb.to_wat(IteratorConsumer)
    end

    test "does not allow reusing existing local name" do
      assert_raise CompileError,
                   ~r[#{TestHelper.location(+8)}: Cannot iterate using existing local name.],
                   fn ->
                     defmodule ReusesLocal do
                       use Orb

                       defw test, {I32, I32}, i: I32, char: I32, alpha: AlphabetIterator do
                         alpha = AlphabetIterator.new()

                         loop char <- alpha do
                           i = i + 1
                         end

                         i
                         char
                       end
                     end

                     Orb.to_wat(ReusesLocal)
                   end
    end
  end

  test "nested loops" do
    defmodule NestedLoop do
      use Orb

      defw nested_loop(), I32, sum: I32 do
        loop i <- 1..4 do
          loop j <- 11..17 do
            sum = sum + 1
          end
        end

        sum
      end
    end

    wat = """
    (module $NestedLoop
      (func $nested_loop (export "nested_loop") (result i32)
        (local $sum i32)
        (local $i i32)
        (local $j i32)
        (i32.const 1)
        (local.set $i)
        (loop $i
          (i32.const 11)
          (local.set $j)
          (loop $j
            (i32.add (local.get $sum) (i32.const 1))
            (local.set $sum)
            (i32.add (local.get $j) (i32.const 1))
            (local.set $j)
            (i32.le_u (local.get $j) (i32.const 17))
            (br_if $j)
          )
          (i32.add (local.get $i) (i32.const 1))
          (local.set $i)
          (i32.le_u (local.get $i) (i32.const 4))
          (br_if $i)
        )
        (local.get $sum)
      )
    )
    """

    assert wat === Orb.to_wat(NestedLoop)
    assert 28 = Wasm.call(NestedLoop, :nested_loop)
  end
end
