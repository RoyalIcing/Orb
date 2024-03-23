defmodule Examples.ArenaTest do
  use ExUnit.Case, async: true

  Code.require_file("arena.exs", __DIR__)
  alias Examples.Arena

  alias OrbWasmtime.Instance

  defmodule A do
    use Orb
    require Arena

    Arena.def(First, pages: 2)
    Arena.def(Second, pages: 3)

    defw test(), {I32, I32, I32, I32} do
      First.alloc(16)
      First.alloc(16)
      Second.alloc(16)
      First.rewind()
      First.alloc(16)
    end

    defw just_enough(), I32, i: I32, final: I32 do
      loop AllocManyTimes do
        final = First.alloc(16)

        i = i + 1
        AllocManyTimes.continue(if: i < 2 * 64 * 1024 / 16)
      end

      final
    end

    defw too_many(), i: I32 do
      loop AllocManyTimes do
        # _ = First.alloc(16)
        First.alloc(16) |> Orb.Stack.drop()

        i = i + 1
        AllocManyTimes.continue(if: i <= 2 * 64 * 1024 / 16)
      end
    end
  end

  test "add func prefixes" do
    assert A.to_wat() =~ ~S"""
           (module $A
             (memory (export "memory") 5)
             (global $Examples.ArenaTest.A.First.bump_offset (mut i32) (i32.const 0))
             (global $Examples.ArenaTest.A.Second.bump_offset (mut i32) (i32.const 131072))
           """

    assert A.to_wat() =~ ~S"""
             (func $Examples.ArenaTest.A.First.alloc (param $byte_count i32) (result i32)
           """

    assert A.to_wat() =~ ~s"""
             (func $Examples.ArenaTest.A.First.rewind
               (i32.const #{0 * Orb.Memory.page_byte_size()})
               (global.set $Examples.ArenaTest.A.First.bump_offset)
           """

    assert A.to_wat() =~ ~s"""
             (func $Examples.ArenaTest.A.Second.rewind
               (i32.const #{2 * Orb.Memory.page_byte_size()})
               (global.set $Examples.ArenaTest.A.Second.bump_offset)
           """

    assert A.to_wat() =~ ~S"""
             (func $test (export "test") (result i32 i32 i32 i32)
               (call $Examples.ArenaTest.A.First.alloc (i32.const 16))
               (call $Examples.ArenaTest.A.First.alloc (i32.const 16))
               (call $Examples.ArenaTest.A.Second.alloc (i32.const 16))
               (call $Examples.ArenaTest.A.First.rewind)
               (call $Examples.ArenaTest.A.First.alloc (i32.const 16))
             )
           """
  end

  test "allocates separate memory offsets" do
    # IO.puts(A.to_wat())
    i = Instance.run(A)
    f = Instance.capture(i, :test, 0)
    assert f.() === {0, 16, 131_072, 0}
  end

  test "just enough allocations" do
    i = Instance.run(A)
    f = Instance.capture(i, :just_enough, 0)
    assert 131_056 = f.()
  end

  test "too many allocations" do
    i = Instance.run(A)
    f = Instance.capture(i, :too_many, 0)
    assert {:error, _} = f.()
  end
end
