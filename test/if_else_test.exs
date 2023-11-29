defmodule IfElseTest do
  use ExUnit.Case, async: true

  use Orb

  test "no inferred type" do
    defmodule A do
      use Orb

      global :export_mutable do
        @a 0
      end

      defw test() do
        if 0 do
          @a = 1
        else
          @a = 2
        end
      end
    end

    assert """
           (module $A
             (global $a (export "a") (mut i32) (i32.const 0))
             (func $test (export "test")
               (i32.const 0)
               (if
                 (then
                   (i32.const 1)
                   (global.set $a)
                 )
                 (else
                   (i32.const 2)
                   (global.set $a)
                 )
               )
             )
           )
           """ === to_wat(A)
  end

  test "inferred i32" do
    defmodule InferredI32 do
      use Orb

      defw test(), I32 do
        if 0 do
          i32(1)
        else
          2
        end
      end
    end

    assert """
           (module $InferredI32
             (func $test (export "test") (result i32)
               (i32.const 0)
               (if (result i32)
                 (then
                   (i32.const 1)
                 )
                 (else
                   (i32.const 2)
                 )
               )
             )
           )
           """ === to_wat(InferredI32)
  end
end
