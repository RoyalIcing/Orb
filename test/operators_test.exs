defmodule OperatorsTest do
  use ExUnit.Case, async: true

  use Orb

  test "default mode" do
    defmodule D1 do
      use Orb

      defw add_i32(n: I32), I32 do
        1 + 2 + n
      end

      defw add_i64(n: I64), I64 do
        1 + 2 + n
      end

      defw add_f32(n: F32), F32 do
        1.0 + 2.0 + n
      end

      defw multiply(a: I32, b: I32) do
        (a * b)
        |> Orb.Stack.drop()

        (2 * a)
        |> Orb.Stack.drop()

        (1 * a)
        |> Orb.Stack.drop()

        (b * 1)
        |> Orb.Stack.drop()

        (0 * a)
        |> Orb.Stack.drop()

        (b * 0)
        |> Orb.Stack.drop()

        i32(2 * 3)
        |> Orb.Stack.drop()
      end

      defw divide(), I32 do
        4 / 2
      end

      defw swap(a: I32, b: I32), {I32, I32} do
        b
        a
      end

      defw fahrenheit_to_celsius(fahrenheit: F32), F32 do
        (fahrenheit - 32.0) * 5.0 / 9.0
      end
    end

    assert Orb.to_wat(D1) == """
           (module $D1
             (func $add_i32 (export "add_i32") (param $n i32) (result i32)
               (i32.add (i32.const 3) (local.get $n))
             )
             (func $add_i64 (export "add_i64") (param $n i64) (result i64)
               (i64.add (i64.const 3) (local.get $n))
             )
             (func $add_f32 (export "add_f32") (param $n f32) (result f32)
               (f32.add (f32.const 3.0) (local.get $n))
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
               (i32.const 2)
             )
             (func $swap (export "swap") (param $a i32) (param $b i32) (result i32 i32)
               (local.get $b)
               (local.get $a)
             )
             (func $fahrenheit_to_celsius (export "fahrenheit_to_celsius") (param $fahrenheit f32) (result f32)
               (f32.div (f32.mul (f32.sub (local.get $fahrenheit) (f32.const 32.0)) (f32.const 5.0)) (f32.const 9.0))
             )
           )
           """
  end

  test "unsigned mode" do
    defmodule U1 do
      use Orb

      wasm_mode(U32)

      defw add(a: I32) do
        i32(1 + 2)
        |> Orb.Stack.drop()

        (a + 2)
        |> Orb.Stack.drop()
      end

      defw multiply(a: I32, b: I32) do
        (a * b)
        |> Orb.Stack.drop()

        (2 * a)
        |> Orb.Stack.drop()

        (1 * a)
        |> Orb.Stack.drop()

        (b * 1)
        |> Orb.Stack.drop()

        (0 * a)
        |> Orb.Stack.drop()

        (b * 0)
        |> Orb.Stack.drop()

        i32(2 * 3)
        |> Orb.Stack.drop()
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
        i64(1 + 2)
        |> Orb.Stack.drop()

        (a + 2)
        |> Orb.Stack.drop()
      end

      defw multiply(a: I64, b: I64) do
        (a * b)
        |> Orb.Stack.drop()

        (2 * a)
        |> Orb.Stack.drop()

        (1 * a)
        |> Orb.Stack.drop()

        (b * 1)
        |> Orb.Stack.drop()

        (0 * a)
        |> Orb.Stack.drop()

        (b * 0)
        |> Orb.Stack.drop()

        i64(2 * 3)
        |> Orb.Stack.drop()
      end

      defw divide(), I64 do
        4 / 2
      end
    end

    assert """
           (module $ExampleS64
             (func $add (export "add") (param $a i64)
               (i64.const 3)
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
               (i64.const 6)
               drop
             )
             (func $divide (export "divide") (result i64)
               (i64.div_s (i64.const 4) (i64.const 2))
             )
           )
           """ === Orb.to_wat(ExampleS64)
  end

  test "float 32-bit work" do
    defmodule F1 do
      use Orb

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

      defw fahrenheit_to_celsius(fahrenheit: F32), F32 do
        (fahrenheit - 32.0) * 5.0 / 9.0
      end
    end

    assert """
           (module $F1
             (func $add (export "add") (result f32)
               (f32.const 3.0)
             )
             (func $multiply (export "multiply") (param $a f32) (param $b f32) (result f32)
               (f32.mul (local.get $a) (local.get $b))
             )
             (func $divide (export "divide") (result f32)
               (f32.const 2.0)
             )
             (func $lab_to_xyz (export "lab_to_xyz") (param $l f32) (param $a f32) (param $b f32) (result f32 f32 f32)
               (f32.const 0.0)
               (f32.const 0.0)
               (f32.const 0.0)
             )
             (func $fahrenheit_to_celsius (export "fahrenheit_to_celsius") (param $fahrenheit f32) (result f32)
               (f32.div (f32.mul (f32.sub (local.get $fahrenheit) (f32.const 32.0)) (f32.const 5.0)) (f32.const 9.0))
             )
           )
           """ === Orb.to_wat(F1)
  end

  test "float 64-bit work" do
    defmodule F64Example do
      use Orb

      defw add(), F64 do
        1.0 + 2.0
      end

      defw multiply(a: F64, b: F64), F64 do
        a * b
      end

      defw divide(), F64 do
        # f64 do: 4.0 / 2.0
        4.0 / 2.0
      end

      defw add_every_flavor(a: I32, b: I64, c: F32, d: F64), F64 do
        F64.convert_i32_s(a)
        |> F64.add(F64.convert_i64_s(b))
        |> F64.add(F64.promote_f32(c))
        |> F64.add(d)
      end

      defw lab_to_xyz(l: F64, a: F64, b: F64), {F64, F64, F64} do
        f64(0.0)
        push(f64(0.0))
        f64(0.0)
      end

      defw fahrenheit_to_celsius(fahrenheit: F64), F64 do
        (fahrenheit - 32.0) * 5.0 / 9.0
      end
    end

    assert """
           (module $F64Example
             (func $add (export "add") (result f64)
               (f64.const 3.0)
             )
             (func $multiply (export "multiply") (param $a f64) (param $b f64) (result f64)
               (f64.mul (local.get $a) (local.get $b))
             )
             (func $divide (export "divide") (result f64)
               (f64.const 2.0)
             )
             (func $add_every_flavor (export "add_every_flavor") (param $a i32) (param $b i64) (param $c f32) (param $d f64) (result f64)
               (f64.add (f64.add (f64.add (f64.convert_i32_s (local.get $a)) (f64.convert_i64_s (local.get $b))) (f64.promote_f32 (local.get $c))) (local.get $d))
             )
             (func $lab_to_xyz (export "lab_to_xyz") (param $l f64) (param $a f64) (param $b f64) (result f64 f64 f64)
               (f64.const 0.0)
               (f64.const 0.0)
               (f64.const 0.0)
             )
             (func $fahrenheit_to_celsius (export "fahrenheit_to_celsius") (param $fahrenheit f64) (result f64)
               (f64.div (f64.mul (f64.sub (local.get $fahrenheit) (f64.const 32.0)) (f64.const 5.0)) (f64.const 9.0))
             )
           )
           """ === Orb.to_wat(F64Example)
  end

  test "numeric mode" do
    defmodule N1 do
      use Orb

      wasm_mode(Orb.Numeric)

      defw add_i32(n: I32), I32 do
        1 + 2 + n
      end

      defw add_i64(n: I64), I64 do
        1 + 2 + n
      end

      defw add_f32(n: F32), F32 do
        1.0 + 2.0 + n
      end

      # defw add_f64(n: F64), F64 do
      #   1.0 + 2.0 + n
      # end

      defw multiply(a: F32, b: F32), F32 do
        a * b
      end

      defw divide(), F32 do
        4.0 / 2.0
      end

      defw lab_to_xyz(l: F32, a: F32, b: F32), {F32, F32, F32} do
        0.0
        push(0.0)
        0.0
      end

      defw double_i32(n: I32), I32 do
        n * 2
      end

      defw double_f32(n: F32), F32 do
        n * 2.0
      end

      defw fahrenheit_to_celsius(fahrenheit: F32), F32 do
        (fahrenheit - 32.0) * 5.0 / 9.0
      end
    end

    assert """
           (module $N1
             (func $add_i32 (export "add_i32") (param $n i32) (result i32)
               (i32.add (i32.const 3) (local.get $n))
             )
             (func $add_i64 (export "add_i64") (param $n i64) (result i64)
               (i64.add (i64.const 3) (local.get $n))
             )
             (func $add_f32 (export "add_f32") (param $n f32) (result f32)
               (f32.add (f32.const 3.0) (local.get $n))
             )
             (func $multiply (export "multiply") (param $a f32) (param $b f32) (result f32)
               (f32.mul (local.get $a) (local.get $b))
             )
             (func $divide (export "divide") (result f32)
               (f32.const 2.0)
             )
             (func $lab_to_xyz (export "lab_to_xyz") (param $l f32) (param $a f32) (param $b f32) (result f32 f32 f32)
               (f32.const 0.0)
               (f32.const 0.0)
               (f32.const 0.0)
             )
             (func $double_i32 (export "double_i32") (param $n i32) (result i32)
               (i32.mul (local.get $n) (i32.const 2))
             )
             (func $double_f32 (export "double_f32") (param $n f32) (result f32)
               (f32.mul (local.get $n) (f32.const 2.0))
             )
             (func $fahrenheit_to_celsius (export "fahrenheit_to_celsius") (param $fahrenheit f32) (result f32)
               (f32.div (f32.mul (f32.sub (local.get $fahrenheit) (f32.const 32.0)) (f32.const 5.0)) (f32.const 9.0))
             )
           )
           """ === Orb.to_wat(N1)
  end
end
