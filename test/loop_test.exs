defmodule LoopTest do
  use ExUnit.Case, async: true

  import Orb, only: [to_wat: 1]
  alias OrbWasmtime.Wasm

  test "loop through chars manually" do
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

    assert wasm_source = to_wat(FileNameSafe)
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

    wasm_source = """
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

    assert wasm_source == to_wat(Loop1To10)
    assert 55 = Wasm.call(Loop1To10, :sum1to10)
  end
end