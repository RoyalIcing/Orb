defmodule Orb.Component do
  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :orb_component_definitions, accumulate: true)
      Module.register_attribute(__MODULE__, :orb_uniforms, accumulate: true)

      def __components__(_), do: []
      defoverridable __components__: 1

      import Orb.Component
    end
  end

  defmacro defc(call, result_type \\ nil, do_block)

  defmacro defc(call, result_type, do: block) do
    {name, args} = Macro.decompose_call(call)

    args =
      case args do
        [] -> []
        [args] when is_list(args) -> args
      end

    args = Macro.expand_once(args, __ENV__)

    dbg(args)

    block_items =
      List.wrap(
        case block do
          {:__block__, _, items} -> List.flatten(items)
          single -> single
        end
      )

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

    # dbg(Macro.to_string(vars))

    new_entry =
      quote generated: true do
        {unquote(name), unquote(block_items)}
      end

    quote bind_quoted: [
            name: name,
            args: args,
            result_type: result_type,
            vars: vars,
            new_entry: new_entry
          ] do
      # Module.put_attribute(__MODULE__, :orb_component_definitions, {name, args, result_type})

      def __components__(context) do
        previous = super(context)

        previous ++
          with do
            # unquote(vars)
            # unquote(new_entry)
          end
      end

      defoverridable __components__: 1
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
