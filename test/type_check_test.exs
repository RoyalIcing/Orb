defmodule TypeCheckTest do
  use ExUnit.Case, async: true

  defmodule PassLocalF32ToI32Add do
    use Orb

    defw example(a: F32), I32 do
      I32.add(a, 1)
    end
  end

  defmodule PassConstantF32ToI32Add do
    use Orb

    defw example(), I32 do
      I32.add(2.0, 1)
    end
  end

  defmodule PassLocalI32ToI32Trunc do
    use Orb

    defw example(a: I32), I32 do
      I32.trunc_f32_s(a)
    end
  end

  defmodule I32AddWithThreeArgs do
    use Orb

    defw example(a: I32), I32 do
      Orb.Instruction.new(:i32, :add, [1, 2, 3])
    end
  end

  defmodule PassConstantI32ToI32Trunc do
    use Orb

    defw example(), I32 do
      I32.trunc_f32_s(5)
    end
  end

  test "raises correct errors" do
    assert_raise Orb.TypeCheckError, "Expected type i32, found f32.", fn ->
      PassLocalF32ToI32Add.to_wat()
    end

    assert_raise Orb.TypeCheckError, "Expected type i32, found f32.", fn ->
      PassConstantF32ToI32Add.to_wat()
    end

    assert_raise Orb.TypeCheckError, "Expected type f32, found i32.", fn ->
      PassLocalI32ToI32Trunc.to_wat()
    end

    assert_raise ArgumentError, "WebAssembly instruction i32.add/2 does not accept a 3rd param.", fn ->
      I32AddWithThreeArgs.to_wat()
    end

    assert_raise Orb.TypeCheckError, "Expected type f32, found i32.", fn ->
      PassConstantI32ToI32Trunc.to_wat()
    end
  end
end
