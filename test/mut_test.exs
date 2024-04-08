defmodule MutTest do
  use ExUnit.Case, async: true

  test "with func parameter" do
    defmodule FuncParam do
      use Orb

      defw double(a: I32), I32, b: I32 do
        with a_ref = mut!(a) do
          a_ref.read * a_ref.read
        end

        mut!(b).write
        mut!(b).read
      end
    end

    wasm_source = """
    (module $FuncParam
      (func $double (export "double") (param $a i32) (result i32)
        (local $b i32)
        (i32.mul (local.get $a) (local.get $a))
        (local.set $b)
        (local.get $b)
      )
    )
    """

    assert Orb.to_wat(FuncParam) == wasm_source
  end

  test "with local variable" do
    defmodule LocalVar do
      use Orb

      defw double(), I32, a: I32, b: I32 do
        a = 42

        with a_ref = mut!(a) do
          a_ref.read * a_ref.read
        end

        mut!(b).write
        mut!(b).read
      end
    end

    wasm_source = """
    (module $LocalVar
      (func $double (export "double") (result i32)
        (local $a i32)
        (local $b i32)
        (i32.const 42)
        (local.set $a)
        (i32.mul (local.get $a) (local.get $a))
        (local.set $b)
        (local.get $b)
      )
    )
    """

    assert Orb.to_wat(LocalVar) == wasm_source
  end
end
