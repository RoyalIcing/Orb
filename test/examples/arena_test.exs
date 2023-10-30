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

    defw test(), I32 do
      First.alloc(16)
    end
  end

  test "add func prefixes" do
    assert ~S"""
           (module $A
             (memory (export "memory") 5)
             (global $Examples.ArenaTest.A.First.bump_offset (mut i32) (i32.const 0))
             (global $Examples.ArenaTest.A.Second.bump_offset (mut i32) (i32.const 131072))
             (func $Examples.ArenaTest.A.First.alloc (param $byte_count i32) (result i32)
               (i32.const 0)
             )
             (func $Examples.ArenaTest.A.Second.alloc (param $byte_count i32) (result i32)
               (i32.const 0)
             )
             (func $test (export "test") (result i32)
               (call $Examples.ArenaTest.A.First.alloc (i32.const 16))
             )
           )
           """ = A.to_wat()
  end
end
