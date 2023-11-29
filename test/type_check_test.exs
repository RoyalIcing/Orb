defmodule TypeCheckTest do
  use ExUnit.Case, async: true

  defmodule PassLocalF32ToI32Add do
    use Orb

    defw example(a: F32), I32 do
      I32.add(a, 1)
    end
  end

  test "passing F32 param to I32.add fails" do
    assert_raise Orb.TypeCheckError,
                 "Instruction i32.add expected type i32, found f32 via Orb.F32.",
                 &PassLocalF32ToI32Add.to_wat/0
  end

  defmodule PassConstantF32ToI32Add do
    use Orb

    defw example(), I32 do
      I32.add(2.0, 1)
    end
  end

  test "passing F32 constant to I32.add fails" do
    assert_raise Orb.TypeCheckError,
                 "Instruction i32.add expected type i32, found f32.",
                 &PassConstantF32ToI32Add.to_wat/0
  end

  defmodule PassLocalI32ToI32Trunc do
    use Orb

    defw example(a: I32), I32 do
      I32.trunc_f32_s(a)
    end
  end

  test "passing I32 param to I32.trunc_f32_s fails" do
    assert_raise Orb.TypeCheckError,
                 "Instruction i32.trunc_f32_s expected type f32, found i32 via Orb.I32.",
                 &PassLocalI32ToI32Trunc.to_wat/0
  end

  defmodule PassConstantI32ToI32Trunc do
    use Orb

    defw example(), I32 do
      I32.trunc_f32_s(5)
    end
  end

  test "passing constant integer to I32.trunc_f32_s fails" do
    assert_raise Orb.TypeCheckError,
                 "Instruction i32.trunc_f32_s expected type f32, found Elixir.Integer.",
                 &PassConstantI32ToI32Trunc.to_wat/0
  end

  defmodule I32AddWithThreeArgs do
    use Orb

    defw example(a: I32), I32 do
      Orb.Instruction.new(:i32, :add, [1, 2, 3])
    end
  end

  test "passing 3rd argument to I32.add fails" do
    assert_raise ArgumentError,
                 "WebAssembly instruction i32.add/2 does not accept a 3rd argument.",
                 &I32AddWithThreeArgs.to_wat/0
  end

  defmodule LocalI32SetToF32 do
    use Orb

    defw example(), a: I32 do
      a = 5.0
    end
  end

  test "setting i32 local to f32 fails" do
    assert_raise Orb.TypeCheckError,
                 "Instruction local.set $a expected type i32 via Orb.I32, found Elixir.Float.",
                 &LocalI32SetToF32.to_wat/0
  end

  defmodule GlobalI32SetToF32 do
    use Orb

    I32.global(a: 42)

    defw example() do
      @a = 5.0
    end
  end

  test "setting i32 global to f32 fails" do
    assert_raise Orb.TypeCheckError,
                 "Instruction global.set $a expected type i32, found Elixir.Float.",
                 &GlobalI32SetToF32.to_wat/0
  end

  defmodule LocalI32SetToI32When do
    use Orb

    defw example(), a: F32 do
      a = I32.when?(1, do: 1, else: 2)
    end
  end

  test "setting f32 local to I32.when? fails" do
    assert_raise Orb.TypeCheckError,
                 "Instruction local.set $a expected type f32 via Orb.F32, found i32.",
                 &LocalI32SetToI32When.to_wat/0
  end
end
