defmodule Examples.ArenaTest do
  use ExUnit.Case, async: true

  Code.require_file("arena.exs", __DIR__)
  alias Examples.Arena

  alias OrbWasmtime.{Instance, Wasm}

  defmodule A do
    use Orb
    require Arena

    Arena.def(First, pages: 2)
    Arena.def(Second, pages: 3)

    Orb.include(A.First)

    defw test() do
      A.First.alloc(16)
    end
  end

  test "add func prefixes" do
    assert ~S"""
           (module $A
             (memory (export "memory") 5)
             (global $First.bump_offset (mut i32) (i32.const 0))
             (global $Second.bump_offset (mut i32) (i32.const 131072))
             (func $Examples.ArenaTest.A.First.alloc (param $byte_count i32) (result i32)
               (i32.const 0)
             )
             (func $test (export "test")
               (call $Examples.ArenaTest.A.First.alloc (i32.const 16))
             )
           )
           """ = A.to_wat()
  end
end
