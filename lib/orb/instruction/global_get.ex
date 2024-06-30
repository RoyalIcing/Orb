defmodule Orb.Instruction.Global.Get do
  @moduledoc false
  defstruct [:push_type, :global_name]

  def new(type, global_name) when is_atom(type) do
    %__MODULE__{push_type: type, global_name: global_name}
  end

  defimpl Orb.ToWat do
    def to_wat(%Orb.Instruction.Global.Get{global_name: global_name}, indent) do
      [indent, "(global.get $", to_string(global_name), ")"]
    end
  end
end
