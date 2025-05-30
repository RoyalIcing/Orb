defmodule WasmexCase do
  use ExUnit.CaseTemplate

  defp log_import() do
    %{
      u32:
        {:fn, [:i32], [],
         fn _context, n ->
           IO.puts([
             IO.ANSI.format([:italic, "u32 "]),
             IO.ANSI.format([:yellow, "#{n}"])
           ])
         end},
      u64:
        {:fn, [:i64], [],
         fn _context, n ->
           IO.puts("u64 #{n}")
         end},
      utf8:
        {:fn, [:i32, :i32], [],
         fn context, ptr, size ->
           string = Wasmex.Memory.read_binary(context.caller, context.memory, ptr, size)
           #  IO.puts(string)
           IO.inspect(string, binaries: :as_strings, syntax_colors: [string: :green])
           #  IO.inspect(string, base: :hex)
         end},
      bytes:
        {:fn, [:i32, :i32], [],
         fn context, ptr, size ->
           bytes = Wasmex.Memory.read_binary(context.caller, context.memory, ptr, size)
           IO.inspect(bytes, binaries: :as_binaries, base: :hex, limit: 1000)
         end},
      putc:
        {:fn, [:i32], [],
         fn _context, utf8char ->
           IO.write(IO.ANSI.format([:cyan, [utf8char]]))
         end},
      four_cc:
        {:fn, [:i32], [],
         fn _context, four_cc ->
           <<a, b, c, d>> = <<four_cc::32>>
           s = <<d, c, b, a>>

           IO.puts([
             IO.ANSI.format([:italic, "4cc "]),
             IO.ANSI.format([
               :yellow,
               [?', s, ?', " ", inspect(s, strings: :as_binaries, base: :hex)]
             ])
           ])
         end}
    }
  end

  setup context do
    wat =
      case Map.fetch(context, :wat) do
        {:ok, wat} -> wat
        :error -> raise "You must set :wat in context"
      end

    imports = Map.get(context, :wasm_imports, %{})
    imports = Map.put_new_lazy(imports, :log, &log_import/0)

    has_memory? = String.contains?(wat, "(memory ")
    # Add memory export to the WAT if needed
    # wat_with_memory =
    #   if not String.contains?(wat, "(memory ") do
    #     String.replace(wat, "(module", "(module\n  (memory (export \"memory\") 1)")
    #     |> dbg()
    #   else
    #     wat
    #   end

    {:ok, pid} = Wasmex.start_link(%{bytes: wat, imports: imports})
    {:ok, store} = Wasmex.store(pid)
    {:ok, instance} = Wasmex.instance(pid)

    {memory, read_binary, write_binary} =
      if has_memory? do
        {:ok, memory} = Wasmex.memory(pid)
        read_binary = &Wasmex.Memory.read_binary(store, memory, &1, &2)
        write_binary = &Wasmex.Memory.write_binary(store, memory, &1, &2)
        {memory, read_binary, write_binary}
      else
        {nil, nil, nil}
      end

    call_function = &Wasmex.call_function(pid, &1, &2)
    set_global = &Wasmex.Instance.set_global_value(store, instance, &1, &2)

    %{
      pid: pid,
      store: store,
      memory: memory,
      instance: instance,
      set_global: set_global,
      call_function: call_function,
      read_binary: read_binary,
      write_binary: write_binary
    }
  end

  defmodule Helper do
    def u32_to_s32(n) when is_integer(n) and n >= 0 and n <= 0xFFFF_FFFF do
      # Convert to signed if the value is above 0x7FFF_FFFF
      if n > 0x7FFF_FFFF do
        n - 0x1_0000_0000
      else
        n
      end
    end
  end
end
