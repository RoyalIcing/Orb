defmodule Orb.IfElse do
  @moduledoc false

  defstruct [:result, :condition, :when_true, :when_false]

  alias Orb.ToWat.Instructions

  # def new(:i32, condition, {:i32_const, a}, {:i32_const, b}) do
  #   [
  #     a,
  #     b,
  #     condition,
  #     :select!
  #   ]
  # end

  def new(condition, when_true) do
    %__MODULE__{
      result: nil,
      condition: optimize_condition(condition),
      when_true: when_true,
      when_false: nil
    }
  end

  def new(condition, when_true, when_false) do
    %__MODULE__{
      result: nil,
      condition: optimize_condition(condition),
      when_true: when_true,
      when_false: when_false
    }
  end

  def new(result, condition, when_true, when_false)
      when not is_nil(result) and not is_nil(when_false) do
    %__MODULE__{
      result: result,
      condition: optimize_condition(condition),
      when_true: when_true,
      when_false: when_false
    }
  end

  def expand(%__MODULE__{} = statement) do
    when_true = statement.when_true |> Orb.Constants.expand_if_needed()
    when_false = statement.when_false |> Orb.Constants.expand_if_needed()
    %{statement | when_true: when_true, when_false: when_false}
  end

  # TODO: remove this, Orb.Instruction should do this for us.
  defp optimize_condition({:i32, :gt_u, {n, 0}}), do: n
  defp optimize_condition(condition), do: condition

  def detecting_result_type(condition, when_true, when_false) do
    result =
      case when_true do
        # TODO: detect actual type instead of assuming i32
        # [{:return, _value}] -> :i32
        _ -> nil
      end

    %__MODULE__{
      result: result,
      condition: condition,
      when_true: when_true,
      when_false: when_false
    }
  end

  defimpl Orb.ToWat do
    import Orb.ToWat.Helpers

    def to_wat(
          %Orb.IfElse{
            result: result,
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
          "(if ",
          if(result,
            do: ["(result ", do_type(result), ")"],
            else: ""
          ),
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

    import Kernel, except: [if: 2]

    defmacro if(condition, [result: result], do: when_true, else: when_false) do
      quote do
        Orb.IfElse.new(
          unquote(result),
          unquote(condition),
          unquote(Orb.__get_block_items(when_true)),
          unquote(Orb.__get_block_items(when_false))
        )
      end
    end

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
          unquote(Orb.__get_block_items(when_true)),
          unquote(Orb.__get_block_items(when_false))
        )
      end
    end

    defmacro if(condition, do: when_true) do
      quote do
        Orb.IfElse.new(
          unquote(condition),
          unquote(Orb.__get_block_items(when_true))
        )
      end
    end
  end
end
