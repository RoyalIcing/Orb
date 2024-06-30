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

  defimpl Orb.TypeNarrowable do
    def type_narrow_to(
          %Orb.Instruction.Global.Get{push_type: Orb.Constants.NulTerminatedString.Slice} =
            global_get,
          Orb.Constants.NulTerminatedString
        ) do
      {global_get |> Orb.Memory.Slice.get_byte_offset(),
       global_get |> Orb.Memory.Slice.get_byte_length()}
    end
  end
end
