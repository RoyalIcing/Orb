defmodule Orb.Component do
  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :orb_component_definitions, accumulate: true)
      Module.register_attribute(__MODULE__, :orb_uniforms, accumulate: true)

      import Orb.Component
    end
  end

  defmacro defc(call, result_type \\ nil, do_block)

  defmacro defc(call, _result_type, do: _block) do
    {name, _args} = Macro.decompose_call(call)

    quote bind_quoted: [name: name] do
      Module.put_attribute(__MODULE__, :orb_component_definitions, {name, :todo})
    end
  end

  defmacro uniform(key_values) do
    quote bind_quoted: [key_values: key_values] do
      Module.put_attribute(__MODULE__, :orb_uniforms, key_values)
    end
  end

  defmacro region(_name, _opts, _do_block) do
    quote do
    end
  end

  def f32(value) when is_float(value) do
    Orb.Instruction.Const.new(:f32, value)
  end
end
