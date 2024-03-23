defmodule Orb.DSL do
  @moduledoc """
  The main DSL which is imported automatically when you call `defw`.
  """

  alias Orb.Instruction
  alias Orb.Ops
  require Ops

  # TODO: remove func, funcp

  defmacro func(call, do: block) do
    define_func(call, :public, [], block, __CALLER__)
  end

  defmacro func(call, locals, do: block) when is_list(locals) do
    define_func(call, :public, [locals: locals], block, __CALLER__)
  end

  defmacro func(call, result_type, do: block) do
    define_func(call, :public, [result: result_type], block, __CALLER__)
  end

  defmacro func(call, result_type, locals, do: block) when is_list(locals) do
    define_func(call, :public, [result: result_type, locals: locals], block, __CALLER__)
  end

  def funcp(options) do
    name = Keyword.fetch!(options, :name)
    Orb.Func.Type.new(name, options[:params], options[:result])
  end

  defmacro funcp(call, do: block) do
    define_func(call, :private, [], block, __CALLER__)
  end

  defmacro funcp(call, locals, do: block) when is_list(locals) do
    define_func(call, :private, [locals: locals], block, __CALLER__)
  end

  defmacro funcp(call, result_type, do: block) do
    define_func(call, :private, [result: result_type], block, __CALLER__)
  end

  defmacro funcp(call, result_type, locals, do: block) when is_list(locals) do
    define_func(call, :private, [result: result_type, locals: locals], block, __CALLER__)
  end

  def __define_func(call, visibility, options, block, env) do
    define_func(call, visibility, options, block, env)
  end

  defp define_func(call, visibility, options, block, env) do
    call = Macro.expand_once(call, __ENV__)

    line =
      case call do
        {_, meta, _} -> meta[:line]
        _ -> env.line
      end

    {name, args} =
      case Macro.decompose_call(call) do
        :error ->
          {
            quote do
              with a = unquote(call), s = Atom.to_string(a) do
                case Macro.inspect_atom(:literal, a) do
                  # Strip : prefix from atom
                  ":" <> other ->
                    other

                  s ->
                    s
                end
              end
            end,
            []
          }

        other ->
          other
      end

    # name = name
    # name = case name_prefix do
    #   nil -> name
    #   prefix -> "#{prefix}.#{name}"
    # end

    exported_names =
      case visibility do
        :public -> quote do: [to_string(unquote(name))]
        :private -> []
      end

    # update_in(args.foo, fn a -> a + 1 end)

    {param_types, runtime_checks} =
      case args do
        [] ->
          {[], []}

        # Keywords
        [args] when is_list(args) ->
          alias Orb.I32

          %{types: types, checks: checks} =
            for {name, type} <- args, reduce: %{types: [], checks: []} do
              %{types: types, checks: checks} ->
                {type, check} =
                  case Macro.expand_literals(type, env) do
                    # Range
                    {:.., _, [min, max]} when min <= max ->
                      {I32,
                       Orb.DSL.assert!(
                         I32.band(
                           Orb.Instruction.local_get(I32, name) |> I32.ge_s(min),
                           Orb.Instruction.local_get(I32, name) |> I32.le_s(max)
                         )
                       )
                       |> Macro.escape()}

                    type when is_atom(type) ->
                      {type, nil}
                  end

                types = [{name, type} | types]

                checks =
                  case check do
                    nil ->
                      checks

                    check ->
                      [check | checks]
                  end

                %{types: types, checks: checks}
            end

          {Enum.reverse(types), Enum.reverse(checks)}

        [_ | _] ->
          raise CompileError,
            line: line,
            file: env.file,
            description: "Function params must use keyword list."
      end

    params =
      for {name, type} <- param_types do
        Macro.escape(%Orb.Func.Param{name: name, type: type})
      end

    result_type = Keyword.get(options, :result, nil) |> Macro.expand_literals(env)

    local_types =
      for {key, type} <- Keyword.get(options, :locals, []) do
        type = Macro.expand_literals(type, env)
        {key, type}
      end

    locals = Map.new(param_types ++ local_types)

    # block = Macro.expand_once(block, __ENV__)

    block_items =
      List.wrap(
        case block do
          {:__block__, _, items} -> List.flatten(items)
          single -> single
        end
      )

    block_items = Macro.expand(block_items, env)
    block_items = do_snippet(locals, block_items)

    block_items = runtime_checks ++ block_items

    quote do
      with do
        result = unquote(result_type)
        block_items = unquote(block_items)

        body_local_types =
          for(%{locals: locals} <- block_items, do: locals)
          |> List.flatten()

        local_types =
          (unquote(local_types) ++ body_local_types)
          |> Keyword.new()

        %Orb.Func{
          name:
            case {@wasm_func_prefix, unquote(name)} do
              {nil, name} -> name
              {prefix, name} -> "#{prefix}.#{name}"
            end,
          params: unquote(params),
          result: result,
          local_types: local_types,
          body: Orb.InstructionSequence.new(result, block_items),
          exported_names: unquote(exported_names)
        }
        |> Orb.Func.narrow_if_needed()
      end
    end
  end

  def do_snippet(locals, block_items) do
    Macro.prewalk(block_items, fn
      # local[at!: offset] = value
      {:=, _meta,
       [
         {{:., _, [Access, :get]}, _,
          [
            {local, _, nil},
            [
              at!: offset
            ]
          ]},
         value
       ]}
      when is_atom(local) and is_map_key(locals, local) ->
        # FIXME: add error message
        bytes_factor = locals[local].byte_count()

        store_instruction =
          case bytes_factor do
            1 -> :store8
            4 -> :store
          end

        local_get_instruction =
          quote do
            Instruction.local_get(unquote(locals[local]), unquote(local))
          end

        # TODO: remove, as should be handled by the custom type implementing
        # the Access protocol.
        computed_offset =
          case {offset, bytes_factor} do
            {0, _} ->
              quote do: unquote(local_get_instruction)

            {offset, 1} ->
              quote do: Orb.I32.add(unquote(local_get_instruction), unquote(offset))

            # We can compute at compile-time
            {offset, factor} when is_integer(offset) ->
              quote do:
                      Orb.I32.add(
                        unquote(local_get_instruction),
                        unquote(offset * factor)
                      )

            # We can only compute at runtime
            {offset, factor} ->
              quote do:
                      Orb.I32.add(
                        unquote(local_get_instruction),
                        I32.mul(unquote(offset), unquote(factor))
                      )
          end

        quote do:
                Orb.Instruction.memory_store(
                  :i32,
                  unquote(store_instruction),
                  offset: unquote(computed_offset),
                  value: unquote(value)
                )

      {:=, _, [{local, _, nil}, input]}
      when is_atom(local) and is_map_key(locals, local) and
             is_struct(:erlang.map_get(local, locals), Orb.VariableReference) ->
        quote do:
                Orb.Instruction.local_set(unquote(locals[local]), unquote(local), unquote(input))

      {:=, _, [{local, _, nil}, input]}
      when is_atom(local) and is_map_key(locals, local) ->
        quote do:
                Orb.Instruction.local_set(unquote(locals[local]), unquote(local), unquote(input))

      {local, _meta, nil} when is_atom(local) and is_map_key(locals, local) ->
        quote do: Orb.VariableReference.local(unquote(local), unquote(locals[local]))

      # @some_global = input
      {:=, _, [{:@, _, [{global, _, nil}]}, input]} when is_atom(global) ->
        # quote do: Orb.Instruction.global_set(unquote(Macro.var(:wasm_global_type, nil)).(unquote(global)), unquote(global), unquote(input))
        quote do:
                Orb.Instruction.global_set(
                  Orb.__lookup_global_type!(unquote(global)),
                  unquote(global),
                  unquote(input)
                )

      # @some_global
      #       node = {:@, meta, [{global, _, nil}]} when is_atom(global) ->
      #         if global == :weekdays_i32 do
      #           dbg(meta)
      #           dbg(node)
      #         end
      #
      #         {:global_get, meta, [global]}

      # e.g. `_ = some_function_returning_value()`
      {:=, _, [{:_, _, nil}, value]} ->
        quote do: Orb.Stack.Drop.new(unquote(value))

      other ->
        other
    end)
  end

  def export(f = %Orb.Func{}, name) when is_binary(name) do
    update_in(f.exported_names, fn names -> [name | names] end)
  end

  def i32(n) when is_integer(n), do: Instruction.i32(:const, n)
  # TODO: should these be removed?
  def i32(false), do: Instruction.i32(:const, 0)
  def i32(true), do: Instruction.i32(:const, 1)
  # TODO: should this be removed?
  def i32(op) when op in Ops.i32(:all), do: {:i32, op}

  def i32(locals) when is_list(locals) do
    Orb.InstructionSequence.new(
      :local_effect,
      for {local, initial_value} when initial_value !== 0 <- locals do
        Orb.Instruction.local_set(Orb.I32, local, initial_value)
      end,
      locals: for({local, _} <- locals, do: {local, Orb.I32})
    )
  end

  def i64(n) when is_integer(n), do: Instruction.i64(:const, n)

  # TODO: move all of these to Orb.Stack
  @doc """
  Pushes a value onto the current stack.
  """
  def push(value)

  def push(tuple)
      when is_tuple(tuple) and elem(tuple, 0) in [:i32, :i32_const, :local_get, :global_get],
      do: tuple

  # FIXME: assumes only 32-bit integer, doesn’t work with 64-bit or float
  def push(n) when is_integer(n), do: Orb.Instruction.wrap_constant!(:i32, n)
  # FIXME: assumes only 32-bit float, doesn’t work with 64-bit float
  def push(n) when is_float(n), do: Orb.Instruction.wrap_constant!(:f32, n)
  def push(%Orb.VariableReference{} = ref), do: ref

  def push(do: %Orb.Instruction{operation: {:local_set, identifier, type}, operands: [value]}),
    do: Orb.Instruction.local_tee(type, identifier, value)

  @doc """
  Push value then run the block. Useful for when you mutate a variable but want its previous value.
  """
  def push(value, do: block) do
    [
      value,
      __get_block_items(block)
      # :pop
    ]
  end

  def typed_call(output_type, f, args) when is_list(args),
    do: Instruction.typed_call(output_type, f, args)

  @doc """
  Call local function `f`.
  """
  @deprecated "Use typed_call/3 instead."
  def call(f), do: Instruction.call(f, [])

  @doc """
  Call local function `f`, passing arguments `args` when list, or single argument otherwise.
  """
  @deprecated "Use typed_call/3 instead."
  def call(f, args)

  def call(f, args) when is_list(args), do: Instruction.call(f, args)
  def call(f, a), do: Instruction.call(f, [a])

  @doc """
  Call local function `f`, passing arguments `a` & `b`.
  """
  @deprecated "Use typed_call/3 instead."
  def call(f, a, b), do: Instruction.call(f, [a, b])

  @doc """
  Call local function `f`, passing argument `a`, `b`, `c`.
  """
  @deprecated "Use typed_call/3 instead."
  def call(f, a, b, c), do: Instruction.call(f, [a, b, c])

  @doc """
  Call local function `f`, passing argument `a`, `b`, `c`, `d`.
  """
  @deprecated "Use typed_call/3 instead."
  def call(f, a, b, c, d), do: Instruction.call(f, [a, b, c, d])

  @doc """
  Call local function `f`, passing argument `a`, `b`, `c`, `d`, `e`.
  """
  @deprecated "Use typed_call/3 instead."
  def call(f, a, b, c, d, e), do: Instruction.call(f, [a, b, c, d, e])

  @doc """
  Call local function `f`, passing argument `a`, `b`, `c`, `d`, `e`, `f`.
  """
  @deprecated "Use typed_call/3 instead."
  def call(f, a, b, c, d, e, f), do: Instruction.call(f, [a, b, c, d, e, f])

  def __expand_identifier(identifier, env) do
    identifier = Macro.expand_once(identifier, env) |> Kernel.to_string()

    case identifier do
      "Elixir." <> _rest = string ->
        string |> Module.split() |> Enum.join(".")

      other ->
        other
    end
  end

  @doc """
  Declare a loop that iterates through a source.
  """
  defmacro loop({:<-, _, [{identifier, _, nil} = var, source]}, do: block)
           when is_atom(identifier) do
    quote do
      with do
        # FIXME: need to support not just I32 but at least I64
        var!(unquote(var)) = Orb.VariableReference.local(unquote(identifier), Orb.I32)
        %Range{first: first, last: last, step: 1} = unquote(source)

        Orb.InstructionSequence.new(
          nil,
          [
            Orb.Instruction.local_set(Orb.I32, unquote(identifier), first),
            %Orb.Loop{
              identifier: unquote(identifier),
              body:
                Orb.InstructionSequence.new(
                  nil,
                  List.flatten([
                    unquote(__get_block_items(block)),
                    Orb.Instruction.local_set(
                      Orb.I32,
                      unquote(identifier),
                      Orb.I32.add(Orb.Instruction.local_get(Orb.I32, unquote(identifier)), 1)
                    ),
                    %Orb.Loop.Branch{
                      identifier: unquote(identifier),
                      if:
                        Orb.I32.le_u(
                          Orb.Instruction.local_get(Orb.I32, unquote(identifier)),
                          last
                        )
                    }
                  ])
                )
            }
          ],
          locals: [{unquote(identifier), Orb.I32}]
        )
      end
    end
  end

  defmacro loop({:<-, _, [item, source]},
             do: block
           ) do
    result_type = nil

    {set_item, identifier} =
      case item do
        {:_, _, _} ->
          {[], "_"}

        _ ->
          {quote bind_quoted: [source: source, item: item] do
             Orb.VariableReference.set(item, source.push_type.value(source))
           end, quote(do: unquote(item).identifier)}
      end

    body =
      quote bind_quoted: [
              source: source,
              identifier: identifier,
              set_item: set_item,
              block_items: __get_block_items(block)
            ] do
        Orb.IfElse.new(
          source.push_type.valid?(source),
          Orb.InstructionSequence.new(
            List.flatten([
              set_item,
              block_items,
              Orb.VariableReference.set(source, source.push_type.next(source)),
              %Orb.Loop.Branch{identifier: identifier}
            ])
          )
        )
      end

    quote do
      %Orb.Loop{
        identifier: unquote(identifier),
        result: unquote(result_type),
        body: unquote(body)
      }
    end
  end

  @doc """
  Declare a loop.
  """
  defmacro loop(identifier, options \\ [], do: block) do
    identifier = __expand_identifier(identifier, __CALLER__)

    result_type =
      Keyword.get(options, :result, nil) |> Macro.expand_literals(__CALLER__)

    while = Keyword.get(options, :while, nil)

    block_items = __get_block_items(block)

    # TODO: is there some way to do this using normal Elixir modules?
    # I think we can define a module inline.
    block_items =
      Macro.prewalk(block_items, fn
        {{:., _, [{:__aliases__, _, [identifier]}, :continue]}, _, []} ->
          quote do: %Orb.Loop.Branch{identifier: unquote(identifier)}

        {{:., _, [{:__aliases__, _, [identifier]}, :continue]}, _, [[if: condition]]} ->
          quote do: %Orb.Loop.Branch{
                  identifier: unquote(identifier),
                  if: unquote(condition)
                }

        other ->
          other
      end)

    block_items =
      case while do
        nil ->
          quote do: Orb.InstructionSequence.new(unquote(block_items))

        condition ->
          quote do:
                  Orb.IfElse.new(
                    unquote(condition),
                    Orb.InstructionSequence.new(
                      List.flatten([
                        unquote(block_items),
                        %Orb.Loop.Branch{identifier: unquote(identifier)}
                      ])
                    )
                  )
      end

    # quote bind_quoted: [identifier: identifier] do
    quote do
      %Orb.Loop{
        identifier: unquote(identifier),
        result: unquote(result_type),
        body: unquote(block_items)
      }
    end
  end

  @doc """
  Run code at compile-time.
  """
  defmacro inline(do: block) do
    quote do
      with do
        # TODO: DRY this up
        # use Orb.RestoreKernel
        import Orb.Global.DSL, only: []
        import Orb.IfElse.DSL, only: []
        import Orb.I32.DSL, only: []
        import Orb.U32.DSL, only: []
        import Orb.S32.DSL, only: []
        import Orb.F32.DSL, only: []
        import Kernel

        unquote(block)
      end
    end
  end

  @doc """
  Run Elixir for-comprehension at compile-time.
  """
  defmacro inline({:for, _meta, [for_arg]}, do: block) do
    quote do
      inline(do: for(unquote(for_arg), do: unquote(block)))
    end
  end

  @doc """
  Used to bring back wasm-mode when inside `inline/1`.
  """
  defmacro wasm(mode \\ Orb.Numeric, do: block) do
    mode = Macro.expand_literals(mode, __CALLER__)
    pre = Orb.__mode_pre(mode)

    quote do
      with do
        unquote(pre)
        import Orb, only: []
        import Orb.DSL
        require Orb.Control, as: Control

        unquote(__get_block_items(block))
      end
    end
  end

  @doc """
  Declare a constant string, which will be extracted to the top of the module, and its address substituted in place.
  """
  def const(value) do
    Orb.Constants.expand_if_needed(value)
  end

  # TODO: add a comptime keyword like Zig: https://kristoff.it/blog/what-is-zig-comptime/

  # TODO: remove, requiring users to use Orb.Control.return() instead.
  @doc """
  Return from a function. You may wish to `push/1` values before returning.
  """
  def return(), do: Orb.Control.Return.new()

  # TODO: remove, requiring users to use Orb.Control.return(value) instead.
  @doc """
  Return from a function if a condition is true.
  """
  def return(value_or_condition)

  def return(if: condition), do: Orb.IfElse.new(condition, Orb.Control.Return.new())
  def return(value), do: Orb.Control.Return.new(value)

  @doc """
  Return from a function with the provided value only if a condition is true.
  """
  def return(value, if: condition), do: Orb.IfElse.new(condition, Orb.Control.Return.new(value))

  @doc """
  A no-op instruction.

  See https://en.wikipedia.org/wiki/NOP_(code)
  """
  def nop(), do: %Orb.Nop{}

  @doc """
  Denote a point in code that should not be reachable. Traps.

  Useful for exhaustive conditionals or code you know will not execute.
  """
  def unreachable!(), do: %Orb.Unreachable{}

  @doc """
  Asserts a condition that _must_ be true, otherwise traps with unreachable.
  """
  def assert!(condition) do
    Orb.IfElse.new(
      condition,
      nop(),
      unreachable!()
    )
  end

  def mut!(term), do: Orb.MutRef.from(term)

  def __get_block_items(block) do
    case block do
      nil -> nil
      {:__block__, _meta, block_items} -> block_items
      single -> [single]
    end
  end
end
