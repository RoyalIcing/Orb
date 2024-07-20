defmodule Orb.Import do
  @moduledoc """
  Define an interface to be imported into WebAssembly.

  Each function declaration is turned into an `(import)` WebAssembly instruction.

  ```elixir
  defmodule Log do
    use Orb.Import, name: :log

    defw logi32(value: I32)
    defw logi64(value: I64)
  end

  defmodule Time do
    use Orb.Import, name: :time

    defw get_unix_time(), I64
  end

  defmodule Example do
    use Orb

    Orb.Import.register(Log)
    Orb.Import.register(Time)

    defw example() do
      Log.logi32(99)

      Log.logi64(Time.get_unix_time())
    end
  end
  ```
  """

  defstruct [:module, :name, :type]

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Orb.DSL.Defw, only: []
      import Orb.Import.DSL
      alias Orb.{I32, I64, F32, F64}

      @orb_import_namespace Keyword.get(opts, :name) ||
                              raise("Option :name must be passed to `use Orb.Import`")

      # Module.register_attribute(__MODULE__, :wasm_imports, accumulate: true, persist: true)

      def __wasm_imports__(_context), do: []
      defoverridable __wasm_imports__: 1

      with do
        require Orb
        Orb.set_func_prefix(inspect(__MODULE__))
      end
    end
  end

  @doc """
  Register an import `module` under `namespace`.

  The `module` is defined via `use Orb.Import`. The `namespace` is the local name the import is registered under.

  For each function defined within `module` an `(import)` instruction is defined in the outputted WebAssembly:

  ```wasm
  (module $example
    (import "namespace" "function1" (func $function1 (param $a i32) (result i32)))
    (import "namespace" "function2" (func $function2 (param $a i32) (result i32)))
    (import "namespace" "function3" (func $function3 (param $a i32) (result i32)))
  )
  ```
  """
  @doc since: "0.0.46"
  defmacro register(module) do
    quote do
      @wasm_imports (for imp <- unquote(module).__wasm_imports__(nil) do
                       imp
                     end)
    end
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Import{module: nil, name: name, type: type}, indent) do
      [indent, ~S|(import "|, to_string(name), ~S|" |, Orb.ToWat.to_wat(type, ""), ?)]
    end

    def to_wat(%Orb.Import{module: module, name: name, type: type}, indent) do
      [
        indent,
        ~S|(import "|,
        to_string(module),
        ~S|" "|,
        to_string(name),
        ~S|" |,
        Orb.ToWat.to_wat(type, ""),
        ?)
      ]
    end
  end

  defmodule DSL do
    @moduledoc """
    DSL for declaring within Elixir module that get converted to `(import …)` expressions in WebAssembly.
    """

    @doc """
    Declare the name and signature of function that will be imported.

    ```elixir
    defmodule Log do
      use Orb.Import, name: :log

      defw(int32(a: I32))
      defw(int64(a: I64))
      defw(two_int32(a: I32, b: I32))
    end
    ```
    """
    defmacro defw(call, result_type \\ nil) do
      alias Elixir.Orb.{Func, Import}

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

      ex_def = Elixir.Orb.DSL.Defw.__define_elixir_def(call, :def, result_type, env)

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
              module: @orb_import_namespace,
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
