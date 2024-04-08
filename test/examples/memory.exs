defmodule Examples.Memory do
  defmodule Copying do
    use Orb

    defmacro __using__(_opts) do
      quote do
        Orb.include(unquote(__MODULE__))
      end
    end

    Memory.pages(2)

    defw memcpy(dest: I32.U8.UnsafePointer, src: I32.U8.UnsafePointer, byte_count: I32),
      i: I32 do
      loop EachByte do
        return(if: I32.eq(i, byte_count))

        dest[at!: i] = src[at!: i]

        i = i + 1
        EachByte.continue()
      end

      # loop EachByte, count: byte_count do
      #   i ->
      #     I32.u! do
      #       memory32_8![dest + i] = memory32_8![src + i]
      #     end
      # end

      #         loop :each_byte do
      #           memory32_8![I32.add(dest, i)] = memory32_8![I32.add(src, i)].unsigned
      #
      #           if I32.lt_u(i, byte_count) do
      #             i = I32.add(i, 1)
      #             :each_byte
      #           end
      #         end

      #         loop :i do
      #           memory32_8![I32.add(dest, i)] = memory32_8![I32.add(src, i)].unsigned
      #
      #           if I32.lt_u(i, byte_count) do
      #             i = I32.add(i, 1)
      #             {:br, :i}
      #           end
      #         end

      #       loop i, 0..byte_count do
      #         memory32_8![I32.add(dest, i)] = memory32_8![I32.add(src, i)].unsigned
      #       end

      #       loop i, I32.lt_u(byte_count), I32.add(1) do
      #         memory32_8![I32.add(dest, i)] = memory32_8![I32.add(src, i)].unsigned
      #       end

      #       loop i, I32.add do
      #         i ->
      #           memory32_8![I32.add(dest, i)] = memory32_8![I32.add(src, i)].unsigned
      #
      #           I32.lt_u(i, byte_count)
      #       end
    end

    def memcpy(dest: dest, src: src, byte_count: byte_count) do
      memcpy(dest, src, byte_count)
    end

    # TODO: add 32-bit-aligned version so we can use faster instructions.
    defw memset(dest: I32.U8.UnsafePointer, u8: I32.U8, byte_count: I32),
      i: I32 do
      loop EachByte do
        return(if: I32.eq(i, byte_count))

        dest[at!: i] = u8

        i = i + 1
        EachByte.continue()
      end
    end

    def memset(dest: dest, u8: u8, byte_count: byte_count) do
      memset(dest, u8, byte_count)
    end
  end

  defmodule BumpAllocator do
    defmodule Constants do
      @page_size 64 * 1024
      @bump_start 1 * @page_size
      def bump_init_offset(), do: @bump_start
    end

    use Orb

    defmacro __using__(opts \\ []) do
      quote do
        import Orb

        cond do
          Module.has_attribute?(__MODULE__, :wasm_use_bump_allocator) ->
            IO.inspect(unquote(opts), label: "use BumpAllocator")

          true ->
            Memory.pages(2)
            # wasm_memory(min_pages: 2)
            # Memory.pages(min: 2)
            # Memory.pages(increase_by: 2)

            I32.global(
              bump_offset: Constants.bump_init_offset(),
              bump_mark: 0
            )

            @wasm_use_bump_allocator true
        end

        Orb.include(unquote(__MODULE__))
        import unquote(__MODULE__)
      end
    end

    defmacro export_alloc() do
      quote do
        Orb.include(unquote(__MODULE__))
      end
    end

    Memory.pages(2)

    I32.global(
      bump_offset: Constants.bump_init_offset(),
      bump_mark: 0
    )

    defwp bump_alloc(size: I32), I32, [] do
      # TODO: check if we have allocated too much
      # and if so, either err or increase the available memory.
      # TODO: Need better maths than this to round up to aligned memory?

      push(@bump_offset) do
        @bump_offset = I32.add(@bump_offset, size)
      end

      # Better syntax?
      # pop(push: @bump_offset) do
      #   @bump_offset = I32.add(@bump_offset, size)
      # end
    end

    defw(alloc(size: I32), I32, do: bump_alloc(size))

    defw free_all() do
      @bump_offset = Constants.bump_init_offset()
    end

    # def alloc(byte_count) do
    #   Orb.DSL.call(:bump_alloc, byte_count)
    # end
  end

  defmodule LinkedLists do
    use Orb
    use BumpAllocator

    # increase_memory pages: 2
    # @wasm_memory 2

    defw cons(hd: I32.UnsafePointer, tl: I32.UnsafePointer), I32.UnsafePointer,
      ptr: I32.UnsafePointer do
      ptr = BumpAllocator.alloc(8)
      ptr[at!: 0] = hd
      ptr[at!: 1] = tl
      ptr
    end

    defw hd(ptr: I32.UnsafePointer), I32.UnsafePointer do
      # Zig: https://godbolt.org/z/bG5zj6bzx
      # ptr[at: 0, fallback: 0x0]
      # ptr |> I32.eqz?(do: 0x0, else: ptr[at!: 0])
      I32.eqz(ptr) |> I32.when?(do: 0x0, else: ptr[at!: 0])
      # ptr &&& ptr[at!: 0]
      # ptr[at!: 0]
    end

    defw tl(ptr: I32.UnsafePointer), I32.UnsafePointer do
      # ptr.unwrap[at!: 1]
      # ptr |> I32.eqz?(do: :unreachable, else: ptr[at!: 1])
      I32.eqz(ptr) |> I32.when?(do: 0x0, else: ptr[at!: 1])
      # ptr[at!: 1]
    end

    defw reverse_in_place(node: I32.UnsafePointer), I32.UnsafePointer,
      prev: I32.UnsafePointer,
      current: I32.UnsafePointer,
      next: I32.UnsafePointer do
      current = node

      # loop current, result: I32 do
      #   0 ->
      #     {:halt, prev}
      #
      #   current ->
      #     next = current[at!: 1]
      #     current[at!: 1] = prev
      #     prev = current
      #     {:cont, next}
      # end

      loop Iterate, result: I32 do
        # return(prev, if: I32.eqz(current))
        if(I32.eqz(current), do: return(prev))

        next = current[at!: 1]
        current[at!: 1] = prev
        prev = current
        current = next
        Iterate.continue()
      end
    end

    defw list_count(ptr: I32.UnsafePointer), I32, count: I32 do
      loop Iterate, result: I32 do
        #           I32.match ptr do
        #             0 ->
        #               return(count)
        #
        #             _ ->
        #               ptr = call(:tl, ptr)
        #               count = I32.add(count, 1)
        #               Iterate.continue()
        #           end

        if I32.eqz(ptr), do: return(count)
        # guard ptr, else: return count
        # if I32.eqz(ptr), return: count
        # return(count, if: I32.eqz(ptr))
        # guard ptr, else_return: count
        # I32.unless ptr, return: count
        # I32.when? ptr, else_return: count
        # I32.when? ptr, else: return(count)

        ptr = __MODULE__.tl(ptr)
        count = count + 1
        Iterate.continue()
      end
    end

    defw list32_sum(ptr: I32), I32, sum: I32 do
      loop Iterate, result: I32 do
        if I32.eqz(ptr), do: return(sum)

        sum = sum + __MODULE__.hd(ptr)
        ptr = __MODULE__.tl(ptr)

        Iterate.continue()
      end
    end

    def hd!(ptr) do
      snippet U32 do
        Memory.load!(I32, ptr)
      end
    end

    def tl!(ptr) do
      snippet U32 do
        Memory.load!(I32, ptr + 4)
      end
    end

    def reverse_in_place!(%Orb.MutRef{read: read, write: write_instruction}) do
      snippet do
        reverse_in_place(read)
        write_instruction
      end
    end

    def start() do
      imports = [
        {:log, :int32,
         fn value ->
           IO.inspect(value, label: "wasm log int32")
           0
         end}
      ]

      OrbWasmtime.Wasm.run_instance(__MODULE__, imports)
    end
  end
end
