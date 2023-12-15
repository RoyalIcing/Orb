defmodule LoopTest do
  use ExUnit.Case, async: true

  import Orb, only: [to_wat: 1]

  test "loop" do
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

    assert wasm_source == to_wat(FileNameSafe)
    # assert Wasm.call(FileNameSafe, "body") == 100
  end
end
