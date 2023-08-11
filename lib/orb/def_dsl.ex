defmodule Orb.DefDSL do

  defmacro defw(call, do: block) do
    define(call, :public, nil, [], block, __CALLER__)
  end

  defmacro defw(call, locals, do: block) when is_list(locals) do
    define(call, :public, nil, locals, block, __CALLER__)
  end

  defmacro defw(call, result, do: block) do
    define(call, :public, result, [], block, __CALLER__)
  end

  defmacro defw(call, result, locals, do: block) when is_list(locals) do
    define(call, :public, result, locals, block, __CALLER__)
  end

  defmacro defwp(call, do: block) do
    define(call, :private, nil, [], block, __CALLER__)
  end

  defmacro defwp(call, locals, do: block) when is_list(locals) do
    define(call, :private, nil, locals, block, __CALLER__)
  end

  defmacro defwp(call, result, do: block) do
    define(call, :private, result, [], block, __CALLER__)
  end

  defmacro defwp(call, result, locals, do: block) when is_list(locals) do
    define(call, :private, result, locals, block, __CALLER__)
  end

  defp define(call, visibility, result, locals, block, env) do
    wasm = Orb.DSL.__define_func(call, visibility, [result: result, locals: locals], block, env)
    ex_def = define_elixir_def(call, visibility)
    quote do
      unquote(ex_def)

      Orb.wasm do
        unquote(wasm)
      end
    end
  end

  defp define_elixir_def(call, visibility) do
    {name, func_args} = Macro.decompose_call(call)
    # arity = length(args)

    def_args = case func_args do
      [] -> []
      [keywords] -> for {keyword, _type} <- keywords do
        Macro.var(keyword, nil)
      end
    end

    meta = elem(call, 1)
    def_call = {name, meta, def_args}

    def_kind = case visibility do
      :public -> :def
      :private -> :defp
    end

    quote do
      unquote(def_kind)(unquote(def_call)) do
        Orb.DSL.call(unquote(name), unquote(def_args))
      end
    end
  end
end
