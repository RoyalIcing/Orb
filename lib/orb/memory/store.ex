defmodule Orb.Memory.Store do
  @moduledoc false

  defstruct push_type: nil,
            store_type: nil,
            store_instruction: :store,
            address: nil,
            align: nil,
            natural_align: nil,
            value: nil

  alias Orb.Memory.Load
  require Orb.Ops |> alias

  def new(type, address, value, opts) when is_atom(type) do
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
      address: address,
      align: align,
      natural_align: natural_align,
      value: value
    }
  end

  def new(primitive_type, load_instruction, address, value, opts)
      when Ops.is_primitive_type(primitive_type) do
    align = Keyword.get(opts, :align)

    {store_instruction, natural_align} =
      Load.store_and_alignment_for(primitive_type, load_instruction)

    Load.validate_align!(align, natural_align)

    %__MODULE__{
      store_type: primitive_type,
      store_instruction: store_instruction,
      address: address,
      align: align,
      natural_align: natural_align,
      value: value
    }
  end

  def offset_by(%__MODULE__{} = store, delta) do
    delta_factor =
      case store do
        %{align: nil, natural_align: natural_align} ->
          natural_align

        %{align: align} ->
          align
      end

    new_address =
      Orb.Numeric.Add.optimized(
        :i32,
        store.address,
        Orb.Numeric.Multiply.optimized(:i32, delta, delta_factor)
      )

    %{store | address: new_address}
  end

  defimpl Orb.ToWat do
    def to_wat(
          %Orb.Memory.Store{
            store_type: type,
            store_instruction: store_instruction,
            address: address,
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
        [" ", Orb.ToWat.Instructions.do_wat(address)],
        [" ", Orb.ToWat.Instructions.do_wat(value)],
        ")"
      ]
    end
  end
end
