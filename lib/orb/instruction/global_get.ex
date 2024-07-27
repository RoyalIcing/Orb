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

  defimpl Orb.ToWasm do
    import Orb.Leb

    def to_wasm(%Orb.Instruction.Global.Get{global_name: global_name}, context) do
      global_index = Orb.ToWasm.Context.fetch_global_index!(context, global_name)

      [0x23, leb128_u(global_index)]
    end
  end

  defimpl Orb.TypeNarrowable do
    def type_narrow_to(
          %Orb.Instruction.Global.Get{push_type: Orb.Str.Slice} =
            global_get,
          Orb.Str
        ) do
      {global_get |> Orb.Memory.Slice.get_byte_offset(),
       global_get |> Orb.Memory.Slice.get_byte_length()}
    end

    def type_narrow_to(as_is, _), do: as_is
  end
end
