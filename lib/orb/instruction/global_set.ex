defmodule Orb.Instruction.Global.Set do
  @moduledoc false
  defstruct push_type: nil, global_name: nil, value: nil

  def new(type, global_name, value) when is_atom(type) do
    %__MODULE__{
      global_name: global_name,
      value: Orb.Instruction.Const.wrap(type, value, "global.set $#{global_name}")
    }
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Instruction.Global.Set{global_name: global_name, value: value}, indent) do
      [
        Orb.ToWat.to_wat(value, indent),
        "\n",
        indent,
        "(global.set $",
        to_string(global_name),
        ")"
      ]
    end
  end

  defimpl Orb.ToWasm do
    import Orb.Leb

    def to_wasm(%Orb.Instruction.Global.Set{global_name: global_name, value: value}, context) do
      global_index = Orb.ToWasm.Context.fetch_global_index!(context, global_name)

      [
        Orb.ToWasm.to_wasm(value, context),
        [0x24, leb128_u(global_index)]
      ]
    end
  end
end
