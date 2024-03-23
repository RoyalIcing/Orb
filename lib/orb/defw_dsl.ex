defmodule Orb.DefwDSL do
  defmacro wasm_mode(mode) do
    mode = Macro.expand_literals(mode, __CALLER__)
    Module.put_attribute(__CALLER__.module, :wasm_mode, mode)
  end

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
    def_kind =
      case visibility do
        :public -> :def
        :private -> :defp
      end

    ex_def = define_elixir_def(call, def_kind, result, env)

    wasm =
      Orb.DSL.__define_func(call, visibility, [result: result, locals: locals], block, env)

    quote do
      unquote(ex_def)

      # TODO: remove wasm do
      Orb.__append_body do
        unquote(wasm)
      end
    end
  end

  def __define_elixir_def(call, def_kind, result_type, env) do
    define_elixir_def(call, def_kind, result_type, env)
  end

  defp define_elixir_def(
         call,
         def_kind,
         result_type,
         %Macro.Env{file: file} = env
       ) do
    {name, func_args} = Macro.decompose_call(call)
    {_, meta, _} = call

    def_args =
      case func_args do
        [] ->
          []

        [keywords] ->
          for {keyword, _type} <- keywords do
            Macro.var(keyword, nil)
          end

        multiple when is_list(multiple) ->
          raise CompileError,
            line: meta[:line],
            file: file,
            description:
              "Cannot define function with multiple arguments, use keyword list instead."
      end

    def_call = {name, meta, def_args}

    params = Orb.Func.Type.params_from_call_args(func_args, env, meta[:line])
    param_types = for %{type: type} <- params, do: type

    quote do
      unquote(def_kind)(unquote(def_call)) do
        Orb.Instruction.typed_call(
          unquote(result_type),
          unquote(param_types),
          case {@wasm_func_prefix, unquote(name)} do
            {nil, name} -> name
            {prefix, name} -> "#{prefix}.#{name}"
          end,
          unquote(def_args)
        )
      end
    end
  end
end
