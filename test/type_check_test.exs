defmodule TypeCheckTest do
  use ExUnit.Case, async: true

  defmodule PassLocalF32ToI32Add do
    use Orb

    defw example(a: F32), I32 do
      I32.add(a, 1)
    end
  end

  test "fails" do
    assert_raise Orb.TypeCheckError, "Expected type i32, found f32.", fn ->
      PassLocalF32ToI32Add.to_wat()
    end
  end
end
