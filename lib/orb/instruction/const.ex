defmodule Orb.Instruction.Const do
  @moduledoc false
  defstruct [:push_type, :value]

  alias require Orb.Ops

  def new(type, value) do
    %__MODULE__{push_type: type, value: value}
  end

  def wrap(type, value) do
    wrap(type, value, "#{inspect(Ops.to_primitive_type(type))}.const")
  end

  def wrap(push_type, value, instruction_identifier) when is_number(value) do
    received_type =
      cond do
        is_integer(value) -> Elixir.Integer
        is_float(value) -> Elixir.Float
      end

    if Ops.types_compatible?(received_type, push_type) do
      new(push_type, value)
    else
      raise Orb.TypeCheckError,
        expected_type: push_type,
        received_type: received_type,
        instruction_identifier: instruction_identifier
    end
  end

  def wrap(push_type, %{push_type: push_type} = instruction, _)
      when Ops.is_primitive_type(push_type) do
    instruction
  end

  def wrap(push_type, %{push_type: other_type} = instruction, instruction_identifier) do
    case Orb.Ops.types_compatible?(push_type, other_type) do
      true ->
        instruction

      false ->
        raise Orb.TypeCheckError,
          expected_type: push_type,
          received_type: other_type,
          instruction_identifier: instruction_identifier
    end
  end

  defimpl Orb.ToWat do
    alias Orb.ToWat.Helpers

    def to_wat(%Orb.Instruction.Const{push_type: push_type, value: value}, indent) do
      [
        indent,
        ["(", Helpers.do_type(push_type), ".const "],
        to_string(value),
        ")"
      ]
    end
  end

  defimpl Orb.ToWasm do
    import Orb.Leb

    defp type_const(:i32), do: 0x41
    defp type_const(:i64), do: 0x42
    defp type_const(:f32), do: 0x43
    defp type_const(:f64), do: 0x44

    defp type_const(custom_type) when is_atom(custom_type),
      do: Orb.CustomType.resolve!(custom_type) |> type_const()

    def to_wasm(
          %Orb.Instruction.Const{
            push_type: type,
            value: number
          },
          _
        ) do
      [
        type_const(type),
        cond do
          is_integer(number) ->
            leb128_s(number)

          is_float(number) and type === :f32 ->
            <<number::32-float-little>>

          is_float(number) and type === :f64 ->
            <<number::64-float-little>>
        end
      ]
    end
  end
end
