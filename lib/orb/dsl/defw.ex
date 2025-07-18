defmodule Orb.DSL.Defw do
  @moduledoc """
  Macros to define WebAssembly functions. Similar to Elixir’s `def` and Nx’s `defn`.
  """

  defmacro wasm_mode(mode) do
    mode = Macro.expand_literals(mode, __CALLER__)
    Module.put_attribute(__CALLER__.module, :wasm_mode, mode)
  end

  defmacro defw({:"::", _meta, [call, result]}, do: block) do
    define(call, :public, result, [], block, __CALLER__)
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
    mod = env.module

    def_kind =
      case visibility do
        :public -> :def
        :private -> :defp
      end

    elixir_def = define_elixir_def(call, def_kind, result, env)

    {func_name, _} = Macro.decompose_call(call)

    func_def =
      Orb.DSL.__define_func(
        call,
        visibility,
        [
          result: result,
          locals: locals
        ],
        block,
        env
      )

    quote generated: true do
      unquote(elixir_def)

      with do
        table_elems = Module.delete_attribute(unquote(mod), :table)
        Module.put_attribute(unquote(mod), :wasm_table_elems, {unquote(func_name), table_elems})

        import Orb, only: []
        unquote(Orb.__mode_pre(Module.get_attribute(mod, :wasm_mode, Orb.Numeric)))

        def __wasm_body__(context) do
          previous = super(context)

          func = unquote(func_def)
          table_elems = unquote(mod).__wasm_table_elems__(func.name)
          table_allocations = unquote(mod).__wasm_table_allocations__()

          func =
            for {mod, key} <- table_elems, reduce: func do
              func ->
                func
                |> Orb.Func.__add_table_elem(
                  Orb.Table.Allocations.fetch_index!(table_allocations, {mod, key})
                )
            end

          previous ++ [func]
        end

        defoverridable __wasm_body__: 1
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

        [keywords] when is_list(keywords) ->
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

    quote generated: true do
      unquote(def_kind)(unquote(def_call)) do
        Orb.Instruction.Call.new(
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
