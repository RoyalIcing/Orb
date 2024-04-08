defmodule Orb.Memory.Load do
  @moduledoc false

  defstruct push_type: nil, load_instruction: :load, offset: nil, align: nil

  require Orb.Ops |> alias

  def new(type, offset, opts) when is_atom(type) do
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
    validate_align!(align, Ops.to_primitive_type(type), load_instruction)

    %__MODULE__{
      push_type: type,
      load_instruction: load_instruction,
      offset: offset,
      align: align
    }
  end

  def new(type, load_instruction, offset, opts) when Ops.is_primitive_type(type) do
    align = Keyword.get(opts, :align)
    validate_align!(align, type, load_instruction)

    %__MODULE__{
      push_type: type,
      load_instruction: load_instruction,
      offset: offset,
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

  def validate_align!(align, primitive_type, load_instruction)

  def validate_align!(nil, _, _), do: nil

  def validate_align!(align, _, _) when align not in [1, 2, 4, 8] do
    raise ArgumentError, "malformed alignment #{align}"
  end

  def validate_align!(align, primitive_type, load_instruction) do
    {_, natural_alignment} = store_and_alignment_for(primitive_type, load_instruction)

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
            offset: offset,
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
        [" ", Orb.ToWat.Instructions.do_wat(offset)],
        ")"
      ]
    end
  end
end
