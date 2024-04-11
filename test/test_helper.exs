ExUnit.start()

defmodule TestHelper do
  defmacro location(plus) do
    caller = __CALLER__
    file = Path.relative_to_cwd(caller.file)
    quote do: "#{unquote(file)}:#{unquote(caller.line) + unquote(plus)}"
  end

  defmacro module_wat(do: block) do
    location = Macro.Env.location(__CALLER__)

    {:module, mod, _, _} =
      Module.create(
        String.to_atom("Elixir.Sample#{location[:line]}"),
        block,
        location
      )

    quote do
      Process.put(Orb.ModuleDefinition.Name, "Sample")
      Orb.to_wat(unquote(mod))
    end
  end

  def wasm_call(source, function), do: do_wasm_call(source, function, [])
  def wasm_call(source, function, arg1), do: do_wasm_call(source, function, [arg1])
  def wasm_call(source, function, arg1, arg2), do: do_wasm_call(source, function, [arg1, arg2])

  defp do_wasm_call(source, function, args) do
    result = OrbWasmtime.Wasm.call_apply(source, to_string(function), args)
    result
  end
end
