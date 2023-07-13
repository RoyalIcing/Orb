defmodule OperatorsTest do
  use ExUnit.Case, async: true

  use Orb

  test "default mode" do
    defmodule A do
      use Orb

      wasm do
        func add(), I32 do
          1 + 2
        end

        func multiply(a: I32, b: I32) do
          a * b
          :drop

          2 * a
          :drop

          1 * a
          :drop

          b * 1
          :drop

          0 * a
          :drop

          b * 0
          :drop

          2 * 3
          :drop
        end
      end
    end

    assert to_wat(A) == """
           (module $A
             (func $add (export "add") (result i32)
               (i32.add (i32.const 1) (i32.const 2))
             )
             (func $multiply (export "multiply") (param $a i32) (param $b i32)
               (i32.mul (local.get $a) (local.get $b))
               drop
               (i32.mul (i32.const 2) (local.get $a))
               drop
               (local.get $a)
               drop
               (local.get $b)
               drop
               (i32.const 0)
               drop
               (i32.const 0)
               drop
               (i32.const 6)
               drop
             )
           )
           """
  end
end
