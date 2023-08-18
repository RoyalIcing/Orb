defmodule TypeCheckTest do
  use ExUnit.Case, async: true

  defmodule PassLocalF32ToI32Add do
    use Orb

    defw example(a: F32), I32 do
      I32.add(a, 1)
    end
  end

  defmodule PassLocalI32ToI32Trunc do
    use Orb

    defw example(a: I32), I32 do
      I32.trunc_f32_s(a)
    end
  end

  test "raises correct errors" do
    assert_raise Orb.TypeCheckError, "Expected type i32, found f32.", fn ->
      PassLocalF32ToI32Add.to_wat()
    end

    assert_raise Orb.TypeCheckError, "Expected type f32, found i32.", fn ->
      PassLocalI32ToI32Trunc.to_wat()
    end
  end
end
