defmodule Orb.Memory.Store do
  @moduledoc false

  defstruct push_type: nil,
            store_type: nil,
            store_instruction: :store,
            offset: nil,
            align: nil,
            value: nil

  alias Orb.Memory.Load
  require Orb.Ops |> alias

  def new(type, offset, value, opts) when is_atom(type) do
    load_instruction =
      cond do
        Ops.is_primitive_type(type) ->
          :load

        type |> Code.ensure_loaded!() |> function_exported?(:load_instruction, 0) ->
          type.load_instruction()

        true ->
          :load
      end

    align = Keyword.get(opts, :align)
    primitive_type = Ops.to_primitive_type(type)

    {store_instruction, natural_align} =
      Load.store_and_alignment_for(primitive_type, load_instruction)

    Load.validate_align!(align, natural_align)

    %__MODULE__{
      store_type: type,
      store_instruction: store_instruction,
      offset: offset,
      align: align,
      value: value
    }
  end

  def new(primitive_type, load_instruction, offset, value, opts)
      when Ops.is_primitive_type(primitive_type) do
    align = Keyword.get(opts, :align)

    {store_instruction, natural_align} =
      Load.store_and_alignment_for(primitive_type, load_instruction)

    Load.validate_align!(align, natural_align)

    %__MODULE__{
      store_type: primitive_type,
      store_instruction: store_instruction,
      offset: offset,
      align: align,
      value: value
    }
  end

  defimpl Orb.ToWat do
    def to_wat(
          %Orb.Memory.Store{
            store_type: type,
            store_instruction: store_instruction,
            offset: offset,
            align: align,
            value: value
          },
          indent
        ) do
      [
        indent,
        "(",
        Orb.ToWat.Helpers.do_type(type),
        ".",
        to_string(store_instruction),
        case align do
          nil -> []
          align -> [" align=", to_string(align)]
        end,
        [" ", Orb.ToWat.Instructions.do_wat(offset)],
        [" ", Orb.ToWat.Instructions.do_wat(value)],
        ")"
      ]
    end
  end
end
