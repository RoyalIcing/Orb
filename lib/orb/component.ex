defmodule Orb.Component do
  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :orb_constants, accumulate: true)
      Module.register_attribute(__MODULE__, :orb_uniforms, accumulate: true)

      @before_compile unquote(__MODULE__).BeforeCompile

      def __components__(_), do: []
      defoverridable __components__: 1

      import Orb.Component
    end
  end

  defmodule BeforeCompile do
    defmacro __before_compile__(%{module: _module}) do
      quote bind_quoted: [] do
        # def __orb_component_uniforms, do: @orb_uniforms

        for {key, value} <- List.flatten(@orb_constants) do
          def __orb_component_constant(key), do: unquote(Macro.escape(value))
        end

        def __orb_component_constant(key), do: raise("Unknown constant #{key}")

        for {key, value} <- List.flatten(@orb_uniforms) do
          def __orb_component_uniform(key), do: unquote(Macro.escape(value))
        end

        def __orb_component_uniform(key), do: raise("Unknown uniform #{key}")
      end
    end
  end

  defmodule DSL do
    defmacro @{name, _meta, _args} do
      quote bind_quoted: [name: name] do
        __orb_component_uniform(name)
      end
    end
  end

  defmodule GlobalConst do
    defstruct [:identifier, :type]
  end

  defmodule UniformReference do
    defstruct [:identifier, :type]
  end

  defmacro defc(name_and_type, do: block) do
    do_defc(name_and_type, block)
  end

  defp do_defc({:"::", _meta, [call, result_type]}, block) do
    {name, args} = Macro.decompose_call(call)

    args =
      case args do
        [] -> []
        [args] when is_list(args) -> args
      end

    args = Macro.expand_once(args, __ENV__)

    def_args =
      for {arg, _type} <- args do
        Macro.var(arg, nil)
      end

    block_items =
      List.wrap(
        case block do
          {:__block__, _, items} -> List.flatten(items)
          single -> single
        end
      )

    instruction =
      quote do
        Orb.InstructionSequence.new(unquote(result_type), unquote(block_items))
        |> case do
          %{body: [single]} -> single
          instructions -> instructions
        end
      end

    vars =
      for {arg_name, type} <- args do
        arg_name = {arg_name, [], nil}

        quote generated: true do
          var!(unquote(arg_name)) = %Orb.VariableReference.Local{
            identifier: unquote(arg_name),
            type: unquote(type)
          }
        end
      end

    {_, meta, _} = call
    def_call = {name, meta, def_args}

    quote do
      def unquote(def_call) do
        use Orb.DSL
        import Orb.Numeric.DSL
        import Orb.Component.DSL

        unquote(instruction)
      end
    end
  end

  defmacro const(key_values) do
    quote bind_quoted: [key_values: key_values] do
      Module.put_attribute(__MODULE__, :orb_constants, key_values)

      for {key, value} <- key_values do
        def unquote({key, [], []}) do
          use Orb.DSL
          import Orb.Numeric.DSL
          import Orb.Component.DSL

          # unquote(Macro.escape(value))

          unquote(
            %GlobalConst{type: value.push_type, identifier: key}
            |> Macro.escape()
          )
        end
      end
    end
  end

  defmacro uniform(key_values) do
    quote bind_quoted: [key_values: key_values] do
      Module.put_attribute(__MODULE__, :orb_uniforms, key_values)
    end
  end

  defmacro region(name, _opts, _do_block) do
    quote do
      defmodule unquote(name) do
        def clear!() do
          :todo
        end

        def size!() do
          0
        end
      end

      # Module.create(
      #   Module.concat([name, Values]),
      #   quote do

      #   end
      # end
    end
  end

  def f32(value) when is_float(value) do
    Orb.Instruction.Const.new(:f32, value)
  end
end
