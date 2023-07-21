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

        func swap(a: I32, b: I32), {I32, I32} do
          b
          a
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
             (func $swap (export "swap") (param $a i32) (param $b i32) (result i32 i32)
               (local.get $b)
               (local.get $a)
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

  test "float 32-bit mode" do
    defmodule F1 do
      use Orb

      wasm F32 do
        func add(), F32 do
          1.0 + 2.0
        end

        func multiply(a: F32, b: F32), F32 do
          a * b
        end

        func divide(), F32 do
          # f32 do: 4.0 / 2.0
          4.0 / 2.0
        end

        func lab_to_xyz(l: F32, a: F32, b: F32), {F32, F32, F32} do
          0.0
          push(0.0)
          0.0
        end
      end
    end

    assert to_wat(F1) == """
           (module $F1
             (func $add (export "add") (result f32)
               (f32.add (f32.const 1.0) (f32.const 2.0))
             )
             (func $multiply (export "multiply") (param $a f32) (param $b f32) (result f32)
               (f32.mul (local.get $a) (local.get $b))
             )
             (func $divide (export "divide") (result f32)
               (f32.div (f32.const 4.0) (f32.const 2.0))
             )
             (func $lab_to_xyz (export "lab_to_xyz") (param $l f32) (param $a f32) (param $b f32) (result f32 f32 f32)
               (f32.const 0.0)
               (f32.const 0.0)
               (f32.const 0.0)
             )
           )
           """
  end
end
