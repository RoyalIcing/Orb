defmodule Orb.IfElse do
  @moduledoc false

  defstruct type: :unknown_effect, condition: nil, when_true: nil, when_false: nil

  alias Orb.Ops

  # def new(:i32, condition, {:i32_const, a}, {:i32_const, b}) do
  #   [
  #     a,
  #     b,
  #     condition,
  #     :select!
  #   ]
  # end

  def new(condition, when_true) do
    type = Ops.extract_type(when_true)
    new_unchecked(type, optimize_condition(condition), when_true, nil)
  end

  def new(condition, when_true, when_false) do
    type = Ops.extract_common_type(when_true, when_false)

    case type do
      nil ->
        raise Orb.TypeCheckError,
          expected_type: Ops.extract_type(when_true),
          received_type: Ops.extract_type(when_false),
          instruction_identifier: "if/else"

      type ->
        new_unchecked(type, optimize_condition(condition), when_true, when_false)
    end
  end

  def new(result, condition, when_true, when_false)
      when not is_nil(result) and not is_nil(when_false) do
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
    alias Orb.ToWat.Instructions
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
        Instructions.do_wat(condition, indent),
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
        [Instructions.do_wat(when_true, "    " <> indent), ?\n],
        ["  ", indent, ")", ?\n],
        if when_false do
          [
            ["  ", indent, "(else", ?\n],
            [Instructions.do_wat(when_false, "    " <> indent), ?\n],
            ["  ", indent, ")", ?\n]
          ]
        else
          []
        end,
        [indent, ")"]
      ]
    end
  end

  defmodule DSL do
    @moduledoc false
    alias Orb.InstructionSequence

    import Kernel, except: [if: 2]

    require Orb.InstructionSequence |> alias

    # Multi-line
    defmacro if(condition, [result: result], do: when_true, else: when_false) do
      quote do
        Orb.IfElse.new(
          unquote(result),
          unquote(condition),
          unquote(Orb.__get_block_items(when_true)) |> InstructionSequence.new(),
          unquote(Orb.__get_block_items(when_false)) |> InstructionSequence.new()
        )
      end
    end

    # Single-line
    defmacro if(condition, result: result, do: when_true, else: when_false) do
      quote do
        Orb.IfElse.new(
          unquote(result),
          unquote(condition),
          unquote(when_true),
          unquote(when_false)
        )
      end
    end

    defmacro if(condition, do: when_true, else: when_false) do
      quote do
        Orb.IfElse.new(
          unquote(condition),
          unquote(Orb.__get_block_items(when_true)) |> InstructionSequence.new(),
          unquote(Orb.__get_block_items(when_false)) |> InstructionSequence.new()
        )
      end
    end

    defmacro if(condition, do: when_true) do
      quote do
        Orb.IfElse.new(
          unquote(condition),
          unquote(Orb.__get_block_items(when_true)) |> InstructionSequence.new()
        )
      end
    end
  end
end
