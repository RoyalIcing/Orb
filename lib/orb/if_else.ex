defmodule Orb.IfElse do
  @moduledoc false

  defstruct pop_type: nil,
            push_type: nil,
            condition: nil,
            when_true: nil,
            when_false: nil

  alias Orb.Ops
  alias Orb.InstructionSequence

  # FIXME: body is never list
  def new(%InstructionSequence{body: [if_else = %__MODULE__{}]}, concat_true) do
    new(if_else, concat_true)
  end

  def new(if_else = %__MODULE__{}, concat_true) when is_struct(concat_true) do
    when_true = InstructionSequence.concat(if_else.when_true, concat_true)
    new(if_else.condition, when_true, if_else.when_false)
  end

  def new(condition, when_true) when is_struct(when_true) do
    {_, type} = Ops.pop_push_of(when_true)
    new(type, condition, when_true, nil)
  end

  # FIXME: body is never list
  def new(%InstructionSequence{body: [if_else = %__MODULE__{}]}, concat_true, concat_false) do
    new(if_else, concat_true, concat_false)
  end

  def new(if_else = %__MODULE__{}, concat_true, concat_false)
      when is_struct(concat_true) and is_struct(concat_false) do
    when_true = InstructionSequence.concat(if_else.when_true, concat_true)
    when_false = InstructionSequence.concat(if_else.when_false, concat_false)
    new(if_else.condition, when_true, when_false)
  end

  # FIXME: body is never list
  def new(condition, when_true, %InstructionSequence{body: []})
      when is_struct(when_true) do
    new(condition, when_true)
  end

  def new(condition, when_true, when_false) when is_struct(when_true) and is_struct(when_false) do
    case {Ops.pop_push_of(when_true), Ops.pop_push_of(when_false)} do
      {same, same = {nil, push_type}} ->
        new(push_type, condition, when_true, when_false)

      {{nil, push_true}, {nil, push_false}} ->
        cond do
          Ops.types_compatible?(push_true, push_false) ->
            new(push_true, condition, when_true, when_false)

          true ->
            raise Orb.TypeCheckError,
              expected_type: push_true,
              received_type: push_false,
              instruction_identifier: :if
        end

      _ ->
        raise ArgumentError,
              "Cannot pop within if/else"
    end
  end

  def new(result, condition, when_true, when_false)
      when is_struct(when_false) or is_nil(when_false) do
    %__MODULE__{
      push_type: result,
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

  defimpl Orb.ToWat do
    import Orb.ToWat.Helpers
    alias require Orb.Ops

    def to_wat(
          %Orb.IfElse{
            push_type: result,
            condition: condition,
            when_true: when_true,
            when_false: when_false
          } = ast,
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
            nil -> ""
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
    rescue
      exception in [Orb.CustomType.InvalidError] ->
        reraise Orb.ToWat.Error, [value: ast, exception: exception], __STACKTRACE__
        # reraise exception, __STACKTRACE__
    end
  end

  defimpl Orb.ToWasm do
    import Orb.ToWasm.Helpers

    def to_wasm(
          %Orb.IfElse{
            push_type: result,
            condition: condition,
            when_true: when_true,
            when_false: when_false
          },
          context
        ) do
      context = Orb.ToWasm.Context.register_loop_identifier(context, nil)

      [
        Orb.ToWasm.to_wasm(condition, context),
        [0x04, if(result, do: to_block_type(result, context), else: 0x40)],
        Orb.ToWasm.to_wasm(when_true, context),
        if(when_false, do: [0x05, Orb.ToWasm.to_wasm(when_false, context)], else: []),
        0x0B
      ]
    end
  end

  defimpl Orb.TypeNarrowable do
    def type_narrow_to(%Orb.IfElse{push_type: current_type} = if_else, narrower_type) do
      case Ops.types_compatible?(current_type, narrower_type) do
        true ->
          %{
            if_else
            | push_type: narrower_type,
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

    import Kernel, except: [if: 2, unless: 2]

    alias require InstructionSequence

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

    defmacro if(do: block) do
      do_cond(block, [], __CALLER__)
    end

    # TODO: this can be replaced with Control.block Identifier result_type do
    # The block is broken with the resulting value e.g.
    # Control.block Identifier result_type do
    #   when some_condition ->
    #     Identifier.break(some_result)
    # end
    # See also: https://github.com/WebAssembly/design/issues/1034#issuecomment-292247623
    # https://musteresel.github.io/posts/2020/01/webassembly-text-br_table-example.html
    defmacro cond(opts, do: block) do
      do_cond(block, opts, __CALLER__)
    end

    def do_cond(block, opts, env) do
      line = env.line
      block_name = "cond_#{line}"

      instructions =
        for {:->, _, [[condition], result]} <- block do
          quote bind_quoted: [
                  condition: condition,
                  result:
                    case result do
                      {:__block__, _meta, items} ->
                        quote do: Orb.InstructionSequence.new(unquote(items))

                      single ->
                        single
                    end,
                  block_name: block_name
                ] do
            case condition do
              true ->
                result

              condition ->
                Orb.IfElse.new(
                  condition,
                  Orb.InstructionSequence.new([
                    result,
                    Orb.Control.break(block_name)
                  ])
                )
                # TODO: need to add branch_type to Orb?
                |> Map.put(:push_type, nil)

                # Orb.InstructionSequence.new([
                #   unquote(result),
                #   Orb.Control.break(unquote(block_name), if: condition),
                #   Orb.Stack.drop(%Orb.Nop{push_type: Orb.I32})
                # ])
            end
          end
        end

      quote do
        with do
          require Orb.Control

          instructions = unquote(instructions)
          opts = unquote(opts)
          result_type = Keyword.get(opts, :result, nil)

          Orb.Control.block unquote(block_name), result_type do
            Orb.InstructionSequence.new(instructions)
          end
        end
      end
    end

    # TODO: remove as it’s being deprecated in Elixir
    # https://x.com/moomerman/status/1838235643983364206
    defmacro unless(condition, clauses) do
      build_unless(condition, clauses)
    end

    defp build_unless(condition, do: when_false) do
      quote bind_quoted: [
              condition: condition,
              when_false: Orb.__get_block_items(when_false)
            ] do
        Orb.IfElse.new(
          condition,
          InstructionSequence.empty(),
          InstructionSequence.new(when_false)
        )
      end
    end

    defp build_unless(condition, do: when_false, else: when_true) do
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
  end
end
