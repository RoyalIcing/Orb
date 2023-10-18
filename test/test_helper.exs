ExUnit.start()

defmodule OrbHelper do
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
      unquote(mod).to_wat()
    end
  end

  defmacro __using__(_) do
    quote do
      require OrbHelper
    end
  end
end
