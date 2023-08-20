defmodule Orb.Control do
  import Orb.DSL, only: [__expand_identifier: 2, __get_block_items: 1]

  @doc """
  Declare a block, useful for structured control flow.
  """
  defmacro block(identifier, result_type \\ nil, do: block) do
    identifier = __expand_identifier(identifier, __CALLER__)
    result_type = Macro.expand_literals(result_type, __CALLER__)

    block_items = __get_block_items(block)

    block_items =
      Macro.prewalk(block_items, fn
        {{:., _, [{:__aliases__, _, [identifier]}, :break]}, _, []} ->
          quote do: %Orb.Block.Branch{identifier: unquote(identifier)}

        {{:., _, [{:__aliases__, _, [identifier]}, :break]}, _, [[if: condition]]} ->
          quote do: %Orb.Block.Branch{
                  identifier: unquote(identifier),
                  if: unquote(condition)
                }

        other ->
          other
      end)

    quote do
      %Orb.Block{
        identifier: unquote(identifier),
        result: unquote(result_type),
        body: unquote(block_items)
      }
    end
  end

  @doc """
  Break from a block.
  """
  def break(identifier), do: {:br, __expand_identifier(identifier, __ENV__)}

  @doc """
  Break from a block if a condition is true.
  """
  def break(identifier, if: condition),
    do: {:br_if, __expand_identifier(identifier, __ENV__), condition}

  def return(), do: :return
end
