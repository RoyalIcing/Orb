defmodule Examples.MemoryTest do
  use ExUnit.Case, async: true

  Code.require_file("memory.exs", __DIR__)
  alias Examples.Memory

  alias OrbWasmtime.Wasm
  alias OrbWasmtime.Instance

  describe "Copying" do
    alias Examples.Memory.Copying

    setup do: %{inst: Instance.run(Copying)}

    test "wasm size" do
      wasm = Wasm.to_wasm(Copying)
      assert byte_size(wasm) == 138
    end

    test "memcpy", %{inst: inst} do
      memcpy = Instance.capture(inst, :memcpy, 3)

      a = 0xA00
      b = 0xB00
      c = 0xC00
      Instance.write_i32(inst, a, 0x12345678)
      memcpy.(b, a, 3)
      assert Instance.read_memory(inst, a, 4) == <<0x78, 0x56, 0x34, 0x12>>
      assert Instance.read_memory(inst, b, 4) == <<0x78, 0x56, 0x34, 0x0>>
      memcpy.(c, a, 0)
      assert Instance.read_memory(inst, c, 4) == <<0x0, 0x0, 0x0, 0x0>>
    end

    test "memset", %{inst: inst} do
      memset = Instance.capture(inst, :memset, 3)

      memset.(0xA00, ?z, 3)
      assert Instance.read_memory(inst, 0xA00, 4) == "zzz\0"

      memset.(0xB00, ?z, 0)
      assert Instance.read_memory(inst, 0xB00, 4) == "\0\0\0\0"
    end
  end

  describe "use Copying" do
    alias Examples.Memory.Copying

    defmodule CopyingUser do
      use Orb
      use Copying

      Memory.pages(1)

      defw example() do
        # TODO: we should add a function to convert a string to a I32.U8.UnsafePointer
        # Or just use Memory.Slice
        Copying.memcpy(
          0x400,
          "hello" |> Orb.Constants.NulTerminatedString.get_base_address(),
          # const("hello").memory_offset,
          3
        )
      end
    end

    test "memcpy" do
      inst = Instance.run(CopyingUser)
      Instance.call(inst, :example)
      assert Instance.read_memory(inst, 0x400, 4) == "hel\0"
    end
  end

  describe "BumpAllocator" do
    alias Memory.BumpAllocator

    test "compiles" do
      Instance.run(BumpAllocator)
    end

    test "wasm size" do
      wasm = Wasm.to_wasm(BumpAllocator)
      assert byte_size(wasm) == 107
    end

    test "single allocation" do
      assert Wasm.call(BumpAllocator, :alloc, 16) == 64 * 1024
    end

    test "multiple allocations" do
      inst = Instance.run(BumpAllocator)
      alloc = Instance.capture(inst, :alloc, 1)
      free_all = Instance.capture(inst, :free_all, 0)

      assert alloc.(0x10) == 0x10000
      assert alloc.(0x10) == 0x10010
      assert alloc.(0x10) == 0x10020
      free_all.()
      assert alloc.(0x10) == 0x10000
      assert alloc.(0x10) == 0x10010
      assert alloc.(0x10) == 0x10020
    end
  end

  describe "LinkedLists" do
    alias Memory.LinkedLists

    test "wasm size" do
      wasm = Wasm.to_wasm(LinkedLists)
      assert byte_size(wasm) == 347
    end

    test "multiple allocations" do
      inst = LinkedLists.start()
      # alloc = Instance.capture(inst, :_test_alloc, 1)
      cons = Instance.capture(inst, :cons, 2)
      count = Instance.capture(inst, :list_count, 1)
      sum = Instance.capture(inst, :list32_sum, 1)

      enum = fn node ->
        Stream.unfold(node, fn node ->
          case Instance.call(inst, :hd, node) do
            0x0 -> nil
            value -> {value, Instance.call(inst, :tl, node)}
          end
        end)
      end

      # i1 = alloc.(0x4)
      # i2 = alloc.(0x4)
      # i3 = alloc.(0x4)
      l1 = cons.(3, 0x0)
      l2 = cons.(4, l1)
      l3 = cons.(5, l2)
      l4 = cons.(6, l3)

      # Instance.write_i32(inst, i1, 0xdeadbeef)
      # Instance.write_i32(inst, i1, 3)
      # Instance.write_i32(inst, i2, 4)
      # Instance.write_i32(inst, i3, 5)

      # Instance.log_memory(inst, 0x10000, 32)

      assert Enum.to_list(enum.(l4)) == [6, 5, 4, 3]
      assert Enum.to_list(enum.(l3)) == [5, 4, 3]
      assert Enum.to_list(enum.(l2)) == [4, 3]
      assert Enum.to_list(enum.(l1)) == [3]

      assert count.(0x0) == 0
      assert count.(l1) == 1
      assert count.(l2) == 2
      assert count.(l3) == 3
      assert count.(l4) == 4

      assert sum.(0x0) == 0
      assert sum.(l1) == 3
      assert sum.(l2) == 7
      assert sum.(l3) == 12
      assert sum.(l4) == 18

      Instance.call(inst, :reverse_in_place, l4)
      # Instance.log_memory(inst, 0x10000, 32)
      assert Enum.to_list(enum.(l1)) == [3, 4, 5, 6]
      # TODO: is this the right behavior?
      assert Enum.to_list(enum.(l2)) == [4, 5, 6]
      assert Enum.to_list(enum.(l3)) == [5, 6]
      assert Enum.to_list(enum.(l4)) == [6]
    end
  end
end
