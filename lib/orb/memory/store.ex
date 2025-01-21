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
  alias require Orb.Ops

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

  defimpl Orb.ToWasm do
    import Orb.Leb

    def to_wasm(
          %Orb.Memory.Store{
            store_type: type,
            store_instruction: store_instruction,
            address: address,
            align: align,
            natural_align: natural_align,
            value: value
          },
          context
        ) do
      type = Orb.Ops.to_primitive_type(type)

      [
        Orb.ToWasm.to_wasm(address, context),
        Orb.ToWasm.to_wasm(value, context),
        do_instruction(type, store_instruction),
        do_align(align || natural_align),
        leb128_u(0)
      ]
    end

    defp do_instruction(:i32, :store), do: 0x36
    defp do_instruction(:i64, :store), do: 0x37
    defp do_instruction(:f32, :store), do: 0x38
    defp do_instruction(:f64, :store), do: 0x39
    defp do_instruction(:i32, :store8), do: 0x3A
    defp do_instruction(:i32, :store16), do: 0x3B
    defp do_instruction(:i64, :store8), do: 0x3C
    defp do_instruction(:i64, :store16), do: 0x3D
    defp do_instruction(:i64, :store32), do: 0x3E

    # Encoded as power of two
    defp do_align(1), do: leb128_u(0)
    defp do_align(2), do: leb128_u(1)
    defp do_align(4), do: leb128_u(2)
    defp do_align(8), do: leb128_u(3)
  end
end
