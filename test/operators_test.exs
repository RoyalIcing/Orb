defmodule OperatorsTest do
  use ExUnit.Case, async: true

  use Orb

  test "default mode" do
    defmodule D1 do
      use Orb

      defw add(a: I32) do
        1 + 2
        :drop

        a + 2
        :drop
      end

      defw multiply(a: I32, b: I32) do
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

      defw divide(), I32 do
        4 / 2
      end

      defw swap(a: I32, b: I32), {I32, I32} do
        b
        a
      end
    end

    assert Orb.to_wat(D1) == """
           (module $D1
             (func $add (export "add") (param $a i32)
               (i32.const 3)
               drop
               (i32.add (local.get $a) (i32.const 2))
               drop
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

      wasm_mode(U32)

      defw add(a: I32) do
        1 + 2
        :drop

        a + 2
        :drop
      end

      defw multiply(a: I32, b: I32) do
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

      defw divide(), I32 do
        4 / 2
      end
    end

    assert """
           (module $U1
             (func $add (export "add") (param $a i32)
               (i32.const 3)
               drop
               (i32.add (local.get $a) (i32.const 2))
               drop
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
           """ === Orb.to_wat(U1)
  end

  test "64-bit signed mode" do
    defmodule ExampleS64 do
      use Orb

      # Orb.numerics!(Orb.S64)
      wasm_mode(Orb.S64)

      defw add(a: I64) do
        1 + 2
        :drop

        a + 2
        :drop
      end

      defw multiply(a: I64, b: I64) do
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

      defw divide(), I64 do
        4 / 2
      end
    end

    assert """
           (module $ExampleS64
             (func $add (export "add") (param $a i64)
               (i32.const 3)
               drop
               (i64.add (local.get $a) (i64.const 2))
               drop
             )
             (func $multiply (export "multiply") (param $a i64) (param $b i64)
               (i64.mul (local.get $a) (local.get $b))
               drop
               (i64.mul (i64.const 2) (local.get $a))
               drop
               (local.get $a)
               drop
               (local.get $b)
               drop
               (i64.const 0)
               drop
               (i64.const 0)
               drop
               (i32.const 6)
               drop
             )
             (func $divide (export "divide") (result i64)
               (i64.div_s (i64.const 4) (i64.const 2))
             )
           )
           """ === Orb.to_wat(ExampleS64)
  end

  test "float 32-bit mode" do
    defmodule F1 do
      use Orb

      wasm_mode(F32)

      defw add(), F32 do
        1.0 + 2.0
      end

      defw multiply(a: F32, b: F32), F32 do
        a * b
      end

      defw divide(), F32 do
        # f32 do: 4.0 / 2.0
        4.0 / 2.0
      end

      defw lab_to_xyz(l: F32, a: F32, b: F32), {F32, F32, F32} do
        0.0
        push(0.0)
        0.0
      end
    end

    assert """
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
           """ === Orb.to_wat(F1)
  end
end
