defmodule StackTest do
  use ExUnit.Case, async: true

  test "block stack" do
    require TestHelper

    assert ~S"""
           (module $Sample
             (func $push_pop (export "push_pop") (param $a i32) (result i32)
               (local $b i32)
               (i32.const 42)
               (local.set $b)
             )
             (func $push_block (export "push_block") (param $a i32) (result i32)
               (local.get $a)
               (i32.add (local.get $a) (i32.const 1))
               (local.set $a)
             )
             (func $push_local_set_tee (export "push_local_set_tee") (result i32)
               (local $b i32)
               (i32.const 5)
               (local.tee $b)
             )
           )
           """ =
             (TestHelper.module_wat do
                use Orb

                defw push_pop(a: I32), I32, b: I32 do
                  Orb.Stack.push(i32(42))
                  b = Orb.Stack.pop(I32)
                end

                defw push_block(a: I32), I32 do
                  Orb.Stack.push a do
                    a = a + 1
                  end
                end

                defw push_local_set_tee(), I32, b: I32 do
                  Orb.Stack.push(b = 5)
                end
              end)
  end
end
