defmodule Orb.Import do
  @moduledoc false

  defstruct [:module, :name, :type]

  defmacro __using__(_) do
    quote do
      import Orb.DefwDSL, only: []
      import Orb.Import.DSL

      # Module.register_attribute(__MODULE__, :wasm_imports, accumulate: true, persist: true)

      def __wasm_imports__(context), do: []
      defoverridable __wasm_imports__: 1

      Orb.set_func_prefix(inspect(__MODULE__))
    end
  end

  defimpl Orb.ToWat do
    alias Orb.ToWat.Instructions

    def to_wat(%Orb.Import{module: nil, name: name, type: type}, indent) do
      ~s[#{indent}(import "#{name}" #{Instructions.do_wat(type)})]
    end

    def to_wat(%Orb.Import{module: module, name: name, type: type}, indent) do
      ~s[#{indent}(import "#{module}" "#{name}" #{Instructions.do_wat(type)})]
    end
  end

  defmodule DSL do
    defmacro defw(call, result_type) do
      alias Elixir.Orb.{DefwDSL, Func, Import}

      env = __CALLER__

      # call = Macro.expand_once(call, __ENV__)
      {name, args} = Macro.decompose_call(call)

      line =
        case call do
          {_, meta, _} -> meta[:line]
          _ -> env.line
        end

      params = Func.Type.params_from_call_args(args, env, line)
      result_type = result_type |> Macro.expand_literals(env)

      ex_def = DefwDSL.__define_elixir_def(call, :def, result_type, env)

      quote do
        unquote(ex_def)

        with do
          def __wasm_imports__(context) do
            full_name =
              case {inspect(__MODULE__), unquote(name)} do
                {nil, name} -> name
                {prefix, name} -> "#{prefix}.#{name}"
              end

            imp = %Import{
              module: :tbd,
              name: unquote(name),
              type: Func.Type.new(full_name, unquote(Macro.escape(params)), unquote(result_type))
            }

            super(context) ++ [imp]
          end

          defoverridable __wasm_imports__: 1
        end
      end
    end
  end
end
