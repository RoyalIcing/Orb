defmodule OperatorsTest do
  use ExUnit.Case, async: true

  use Orb

  test "default mode" do
    defmodule D1 do
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

        func divide(), I32 do
          4 / 2
        end
      end
    end

    assert to_wat(D1) == """
           (module $D1
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
             (func $divide (export "divide") (result i32)
               (i32.div_s (i32.const 4) (i32.const 2))
             )
           )
           """
  end

  test "unsigned mode" do
    defmodule U1 do
      use Orb

      wasm U32 do
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

        func divide(), I32 do
          4 / 2
        end
      end
    end

    assert to_wat(U1) == """
           (module $U1
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
             (func $divide (export "divide") (result i32)
               (i32.div_u (i32.const 4) (i32.const 2))
             )
           )
           """
  end
end
