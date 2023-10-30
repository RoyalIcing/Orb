defmodule Examples.Arena do
  # See https://www.rfleury.com/p/untangling-lifetimes-the-arena-allocator

  use Orb

  defmacro def(name, opts) do
    # module_name = Module.concat(__MODULE__, Macro.expand_literals(name, __CALLER__))
    # Module.put_attribute(module_name, :wasm_func_prefix, module_name)

    quote do
      require Orb.Memory
      page_offset = Orb.Memory.pages(unquote(opts[:pages]))

      offset_global_name =
        String.to_atom("#{Macro.inspect_atom(:literal, unquote(name))}.bump_offset")

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

      module_name = Module.concat(__MODULE__, unquote(name))

      Module.create(module_name, quote do
        use Orb

        # offset_global_name = unquote(offset_global_name)

        set_func_prefix(inspect(unquote(module_name)))

        # @wasm_func_prefix inspect(unquote(module_name))
        # Module.put_attribute(__MODULE__, :wasm_func_prefix, inspect(unquote(module_name)))
        # IO.puts("put_attribute")
        # IO.inspect(__MODULE__)
        # IO.inspect(inspect(unquote(module_name)))

        # https://man7.org/linux/man-pages/man3/alloca.3.html
        defw alloc(byte_count: I32), I32.UnsafePointer do
          0x0
          # push(global_get(unquote(offset_global_name))) do
            # @bump_offset = I32.add(@bump_offset, size)
          # end
        end
      end, unquote(Macro.Env.location(__CALLER__)))

      # alias module_name
      # require module_name, as: unquote(name)
    end
  end
end
