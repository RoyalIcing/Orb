defmodule Examples.Arena do
  # See https://www.rfleury.com/p/untangling-lifetimes-the-arena-allocator

  use Orb

  alias Orb.Instruction

  def alloc_impl(values_mod, byte_count) do
    offset_global_name = values_mod.offset_global_name()
    start_offset = values_mod.start_offset()
    end_offset = values_mod.end_offset()

    Orb.snippet Orb.S32, new_ptr: I32.UnsafePointer do
      new_ptr = Instruction.global_get(Orb.I32, offset_global_name)
      Instruction.global_set(Orb.I32, offset_global_name, new_ptr + byte_count)

      if Instruction.global_get(Orb.I32, offset_global_name) > end_offset * Orb.Memory.page_byte_size() do
        unreachable!()
      end

      new_ptr
    end
  end

  defmacro def(name, opts) do
    # module_name = Module.concat(__MODULE__, Macro.expand_literals(name, __CALLER__))
    # Module.put_attribute(module_name, :wasm_func_prefix, module_name)

    quote do
      require Orb.Memory

      module_name = Module.concat(__MODULE__, unquote(name))
      page_count = unquote(opts[:pages])
      page_offset = Orb.Memory.pages(page_count)
      offset_global_name =
        String.to_atom("#{Macro.inspect_atom(:literal, module_name)}.bump_offset")

      Module.create(
        Module.concat([__MODULE__, unquote(name), Values]),
        quote do
          def start_offset(), do: unquote(page_offset)
          def end_offset(), do: unquote(page_offset + page_count)
          def offset_global_name(), do: unquote(offset_global_name)
        end,
        unquote(Macro.Env.location(__CALLER__))
      )


      global(
        do: [
          {offset_global_name, page_offset * 64 * 1024}
        ]
      )

      # defmodule unquote(name) do
      #   use Orb

      #   offset_global_name = unquote(offset_global_name)

      #   # https://man7.org/linux/man-pages/man3/alloca.3.html
      #   defw alloc(byte_count: I32), I32.UnsafePointer do
      #     push(global_get(unquote(offset_global_name))) do
      #       # @bump_offset = I32.add(@bump_offset, size)
      #     end
      #   end
      # end

      with do
        Orb.__mode_pre(Orb.S32)

        defmodule unquote(name) do
          use Orb

          alias __MODULE__.Values

          set_func_prefix(inspect(__MODULE__))

          # https://man7.org/linux/man-pages/man3/alloca.3.html
          defw alloc(byte_count: I32), I32.UnsafePointer, new_ptr: I32.UnsafePointer do
            # Examples.Arena.alloc_impl(Values, byte_count)
            Examples.Arena.alloc_impl(Values, Instruction.local_get(I32, :byte_count))
          end
        end
      end

      # Orb.include(module_name)
      Orb.include(__MODULE__.unquote(name))
      alias __MODULE__.{unquote(name)}

      # require module_name, as: unquote(name)
    end
  end
end
