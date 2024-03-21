defmodule Orb.IfElse do
  @moduledoc false

  defstruct type: :unknown_effect, condition: nil, when_true: nil, when_false: nil

  alias Orb.Ops

  def new(if_else = %__MODULE__{}, concat_true) when is_struct(concat_true) do
    when_true = Orb.InstructionSequence.concat(if_else.when_true, concat_true)
    type = Ops.typeof(when_true)
    new_unchecked(type, if_else.condition, when_true, if_else.when_false)
  end

  def new(condition, when_true) when is_struct(when_true) do
    type = Ops.typeof(when_true)
    new_unchecked(type, optimize_condition(condition), when_true, nil)
  end

  def new(condition, when_true, when_false) when is_struct(when_true) and is_struct(when_false) do
    type = Ops.extract_common_type(when_true, when_false)

    case type do
      nil ->
        raise Orb.TypeCheckError,
          expected_type: Ops.typeof(when_true),
          received_type: Ops.typeof(when_false),
          instruction_identifier: "if/else"

      type ->
        new_unchecked(type, optimize_condition(condition), when_true, when_false)
    end
  end

  def new(result, condition, when_true, when_false)
      when not is_nil(result) and is_struct(when_false) do
    new_unchecked(result, optimize_condition(condition), when_true, when_false)
  end

  defp new_unchecked(result, condition, when_true, when_false) when not is_nil(result) do
    %__MODULE__{
      type: result,
      condition: condition,
      when_true: when_true,
      when_false: when_false
    }
  end

  def expand(%__MODULE__{} = statement) do
    when_true = statement.when_true |> Orb.Constants.expand_if_needed()
    when_false = statement.when_false |> Orb.Constants.expand_if_needed()
    %{statement | when_true: when_true, when_false: when_false}
  end

  # TODO: probably remove this.
  defp optimize_condition({:i32, :gt_u, {n, 0}}), do: n
  defp optimize_condition(condition), do: condition

  defimpl Orb.ToWat do
    import Orb.ToWat.Helpers
    require Orb.Ops |> alias

    def to_wat(
          %Orb.IfElse{
            type: result,
            condition: condition,
            when_true: when_true,
            when_false: when_false
          },
          indent
        )
        when not is_nil(condition) do
      [
        Orb.ToWat.to_wat(condition, indent),
        [
          "\n",
          indent,
          "(if",
          case result do
            effect when Ops.is_effect(effect) -> ""
            type -> [" (result ", do_type(type), ")"]
          end,
          ?\n
        ],
        ["  ", indent, "(then", ?\n],
        Orb.ToWat.to_wat(when_true, "    " <> indent),
        ["  ", indent, ")", ?\n],
        if when_false do
          [
            ["  ", indent, "(else", ?\n],
            Orb.ToWat.to_wat(when_false, "    " <> indent),
            ["  ", indent, ")", ?\n]
          ]
        else
          []
        end,
        [indent, ")"]
      ]
    end
  end

  defimpl Orb.TypeNarrowable do
    def type_narrow_to(%Orb.IfElse{type: current_type} = if_else, narrower_type) do
      case Ops.types_compatible?(current_type, narrower_type) do
        true ->
          %{
            if_else
            | type: narrower_type,
              when_true: Orb.TypeNarrowable.type_narrow_to(if_else.when_true, narrower_type),
              when_false: Orb.TypeNarrowable.type_narrow_to(if_else.when_false, narrower_type)
          }

        false ->
          # raise "Incompatible types Elixir.Integer and #{inspect(narrower_type)}."
          if_else
      end
    end

    def type_narrow_to(%Orb.IfElse{} = if_else, _), do: if_else
  end

  defmodule DSL do
    @moduledoc false

    import Kernel, except: [if: 2]

    require Orb.InstructionSequence |> alias

    # Multi-line
    defmacro if(condition, [result: result], do: when_true, else: when_false) do
      quote bind_quoted: [
              condition: condition,
              result: result,
              when_true: Orb.__get_block_items(when_true),
              when_false: Orb.__get_block_items(when_false)
            ] do
        Orb.IfElse.new(
          result,
          condition,
          InstructionSequence.new(when_true),
          InstructionSequence.new(when_false)
        )
      end
    end

    # Single-line
    defmacro if(condition, result: result, do: when_true, else: when_false) do
      quote bind_quoted: [
              result: result,
              condition: condition,
              when_true: when_true,
              when_false: when_false
            ] do
        Orb.IfElse.new(result, condition, when_true, when_false)
      end
    end

    defmacro if(condition, do: when_true, else: when_false) do
      quote bind_quoted: [
              condition: condition,
              when_true: Orb.__get_block_items(when_true),
              when_false: Orb.__get_block_items(when_false)
            ] do
        Orb.IfElse.new(
          condition,
          InstructionSequence.new(when_true),
          InstructionSequence.new(when_false)
        )
      end
    end

    defmacro if(condition, do: when_true) do
      quote bind_quoted: [
              condition: condition,
              when_true: Orb.__get_block_items(when_true)
            ] do
        Orb.IfElse.new(
          condition,
          InstructionSequence.new(when_true)
        )
      end
    end
  end
end
