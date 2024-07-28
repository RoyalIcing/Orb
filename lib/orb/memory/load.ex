defmodule Orb.Memory.Load do
  @moduledoc false

  defstruct push_type: nil, load_instruction: :load, address: nil, align: nil

  require Orb.Ops |> alias

  def new(type, address, opts) when is_atom(type) do
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
    {_, natural_alignment} = store_and_alignment_for(primitive_type, load_instruction)
    validate_align!(align, natural_alignment)

    %__MODULE__{
      push_type: type,
      load_instruction: load_instruction,
      address: address,
      align: align
    }
  end

  def new(primitive_type, load_instruction, address, opts)
      when Ops.is_primitive_type(primitive_type) do
    align = Keyword.get(opts, :align)
    {_, natural_alignment} = store_and_alignment_for(primitive_type, load_instruction)
    validate_align!(align, natural_alignment)

    %__MODULE__{
      push_type: primitive_type,
      load_instruction: load_instruction,
      address: address,
      align: align
    }
  end

  def store_and_alignment_for(primitive_type, load_instruction) do
    case load_instruction do
      i when i in [:load8_s, :load8_u] ->
        {:store8, 1}

      i when i in [:load16_s, :load16_u] ->
        {:store16, 2}

      i when i in [:load32_s, :load32_u] ->
        {:store32, 4}

      :load ->
        case primitive_type do
          t when t in [:i32, :f32] -> {:store, 4}
          t when t in [:i64, :f64] -> {:store, 8}
        end
    end
  end

  def validate_align!(align, natural_alignment)

  def validate_align!(nil, _), do: nil

  def validate_align!(align, _) when align not in [1, 2, 4, 8] do
    raise ArgumentError, "malformed alignment #{align}"
  end

  def validate_align!(align, natural_alignment) do
    if align > natural_alignment do
      raise ArgumentError,
            "alignment #{align} must not be larger than natural #{natural_alignment}"
    end
  end

  defimpl Orb.ToWat do
    def to_wat(
          %Orb.Memory.Load{
            push_type: type,
            load_instruction: load_instruction,
            address: address,
            align: align
          },
          indent
        ) do
      [
        indent,
        "(",
        Orb.ToWat.Helpers.do_type(type),
        ".",
        to_string(load_instruction),
        case align do
          nil -> []
          align -> [" align=", to_string(align)]
        end,
        [" ", Orb.ToWat.Instructions.do_wat(address)],
        ")"
      ]
    end
  end

  defimpl Orb.ToWasm do
    import Orb.Leb

    def to_wasm(
          %Orb.Memory.Load{
            push_type: type,
            load_instruction: load_instruction,
            address: address,
            align: align
          },
          context
        ) do
      type = Orb.Ops.to_primitive_type(type)
      {_, natural_alignment} = Orb.Memory.Load.store_and_alignment_for(type, load_instruction)

      [
        Orb.ToWasm.to_wasm(address, context),
        do_instruction(type, load_instruction),
        do_align(align || natural_alignment),
        leb128_u(0)
      ]
    end

    defp do_instruction(:i32, :load), do: 0x28
    defp do_instruction(:i64, :load), do: 0x29
    defp do_instruction(:f32, :load), do: 0x2A
    defp do_instruction(:f64, :load), do: 0x2B
    defp do_instruction(:i32, :load8_s), do: 0x2C
    defp do_instruction(:i32, :load8_u), do: 0x2D
    defp do_instruction(:i32, :load16_s), do: 0x2E
    defp do_instruction(:i32, :load16_u), do: 0x2F
    defp do_instruction(:i64, :load8_s), do: 0x30
    defp do_instruction(:i64, :load8_u), do: 0x31
    defp do_instruction(:i64, :load16_s), do: 0x32
    defp do_instruction(:i64, :load16_u), do: 0x33
    defp do_instruction(:i64, :load32_s), do: 0x34
    defp do_instruction(:i64, :load32_u), do: 0x35

    # Encoded as power of two
    defp do_align(1), do: leb128_u(0)
    defp do_align(2), do: leb128_u(1)
    defp do_align(4), do: leb128_u(2)
    defp do_align(8), do: leb128_u(3)
  end
end
