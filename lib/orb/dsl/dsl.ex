defmodule Orb.DSL do
  @moduledoc """
  The main DSL which is imported automatically when you call `defw`.
  """

  alias Orb.Instruction
  alias Orb.Ops
  require Ops

  defmacro __using__(_opts) do
    quote do
      import Kernel,
        except: [
          if: 2,
          unless: 2,
          @: 1,
          +: 2,
          -: 2,
          *: 2,
          /: 2,
          <: 2,
          >: 2,
          <=: 2,
          >=: 2,
          ===: 2,
          !==: 2,
          not: 1,
          or: 2
        ]

      import Orb.DSL
      require Orb.Control, as: Control
      import Orb.IfElse.DSL
    end
  end

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
                {types, check} =
                  Macro.expand_literals(type, env)
                  |> case do
                    # Range
                    {:.., _, [min, max]} when min <= max ->
                      {[{name, I32} | types],
                       Orb.DSL.assert!(
                         I32.band(
                           Orb.Instruction.local_get(I32, name) |> I32.ge_s(min),
                           Orb.Instruction.local_get(I32, name) |> I32.le_s(max)
                         )
                       )
                       |> Macro.escape()}

                    type when is_atom(type) ->
                      {[{name, type} | types], nil}
                  end

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
        case type do
          Orb.Str ->
            [
              %Orb.Func.Param{name: "#{name}.ptr", type: Orb.I32.UnsafePointer},
              %Orb.Func.Param{name: "#{name}.size", type: Orb.I32}
            ]

          type ->
            %Orb.Func.Param{name: name, type: type}
        end
      end
      |> List.flatten()

    result_type = Keyword.get(options, :result, nil) |> Macro.expand_literals(env)

    local_vars =
      for {name, type} <- Keyword.get(options, :locals, []) do
        type = Macro.expand_literals(type, env)

        case type do
          Orb.Str ->
            {name, Orb.Str}

          type ->
            {name, type}
        end
      end
      |> List.flatten()

    local_type_defs =
      for {name, type} <- Keyword.get(options, :locals, []) do
        type = Macro.expand_literals(type, env)

        case type do
          Orb.Str ->
            [
              {:"#{name}.ptr", Orb.I32.UnsafePointer},
              {:"#{name}.size", Orb.I32}
            ]

          type ->
            {name, type}
        end
      end
      |> List.flatten()

    block_items =
      List.wrap(
        case block do
          {:__block__, _, items} -> List.flatten(items)
          single -> single
        end
      )

    block_items = Macro.expand(block_items, env)

    local_inline_defs =
      for {:local, _, [keyword]} <- Macro.prewalker(block_items) do
        Macro.expand_literals(keyword, env)
      end
      |> List.flatten()

    locals = Map.new(param_types ++ local_vars ++ local_inline_defs)

    # local_var_refs =
    #   Enum.map(local_inline_defs, fn {key, type} ->
    #     quote do
    #       unquote(key) = Orb.VariableReference.local(unquote(key), unquote(type))
    #     end
    #   end)

    block_items = do_snippet(locals, block_items)
    block_items = runtime_checks ++ block_items

    quote do
      with do
        result = unquote(result_type)
        block_items = unquote(block_items)

        body_local_types =
          for(%{locals: locals} <- block_items, do: locals)
          |> List.flatten()

        # |> List.keysort(0)

        local_types =
          (unquote(local_type_defs) ++ body_local_types ++ unquote(local_inline_defs))
          |> Keyword.new()

        %Orb.Func{
          name:
            case {@wasm_func_prefix, unquote(name)} do
              {nil, name} -> name
              {prefix, name} -> "#{prefix}.#{name}"
            end,
          params: unquote(Macro.escape(params)),
          result: result,
          local_types: local_types,
          body:
            with do
              Orb.InstructionSequence.new(result, block_items)
            end,
          exported_names: unquote(exported_names)
        }
        |> Orb.Func.narrow_if_needed()
      end
    end
  end

  defguardp is_local(name, locals) when is_atom(name) and is_map_key(locals, name)

  def do_match(left, right, locals)

  def do_match({:_, _, nil}, input, _locals) do
    quote do: Orb.Stack.Drop.new(unquote(input))
  end

  # Special casing for when assigning a Orb.Str to another Orb.Str
  # TODO: composite types that allow any custom type to do this.
  def do_match({local_a, _, nil}, {local_b, _, nil}, locals)
      when is_atom(local_b) and is_map_key(locals, local_a) and
             is_atom(local_b) and is_map_key(locals, local_b) and
             :erlang.map_get(local_a, locals) == Orb.Str and
             :erlang.map_get(local_b, locals) == Orb.Str do
    quote bind_quoted: [local_a: local_a, local_b: local_b] do
      Orb.InstructionSequence.new([
        Orb.Instruction.local_set(
          Orb.I32.UnsafePointer,
          :"#{local_a}.ptr",
          Orb.VariableReference.local(local_b, Orb.Str)[:ptr]
        ),
        Orb.Instruction.local_set(
          Orb.I32,
          :"#{local_a}.size",
          Orb.VariableReference.local(local_b, Orb.Str)[:size]
        )
      ])
    end
  end

  # Special casing for when assigning a call returning Orb.Str to another Orb.Str
  # TODO: composite types that allow any custom type to do this.
  def do_match({local, _, nil}, source, locals)
      when is_atom(local) and is_map_key(locals, local) and
             :erlang.map_get(local, locals) == Orb.Str do
    quote bind_quoted: [local: local, source: source] do
      Orb.InstructionSequence.new(nil, [
        source,
        Orb.Instruction.local_set(
          Orb.I32,
          :"#{local}.size"
        ),
        Orb.Instruction.local_set(
          Orb.I32.UnsafePointer,
          :"#{local}.ptr"
        )
      ])
    end
  end

  def do_match({local, _, nil}, input, locals)
      when is_atom(local) and is_map_key(locals, local) and
             is_struct(:erlang.map_get(local, locals), Orb.VariableReference) do
    quote do: Orb.Instruction.local_set(unquote(locals[local]), unquote(local), unquote(input))
  end

  def do_match({local, _, nil}, input, locals)
      when is_atom(local) and is_map_key(locals, local) do
    quote do: Orb.Instruction.local_set(unquote(locals[local]), unquote(local), unquote(input))
  end

  # De-structuring a tuple of two values
  def do_match({{a, _, nil}, {b, _, nil}}, input, locals)
      when is_local(a, locals) and is_local(b, locals) do
    quote do:
            Orb.InstructionSequence.new([
              unquote(input),
              Orb.VariableReference.local(unquote(b), unquote(locals[b]))
              |> Orb.VariableReference.as_set(),
              Orb.VariableReference.local(unquote(a), unquote(locals[a]))
              |> Orb.VariableReference.as_set()
            ])
  end

  # def do_match({local, _, nil}, input, locals)
  # when is_atom(local) and is_map_key(locals, local) do
  # end
  # {{:., _, [Access, :get]}, _,
  # [
  #   {local, _, nil},
  #   [:ptr]
  # ]}

  # @some_global = input
  def do_match({:@, _, [{global, _, nil}]}, input, _locals) do
    quote do:
            Orb.Instruction.Global.Set.new(
              Orb.__lookup_global_type!(unquote(global)),
              unquote(global),
              unquote(input)
            )
  end

  def do_match(_left, _right, _locals), do: nil

  def do_snippet(locals, block_items) do
    # dbg(locals)
    Macro.prewalk(block_items, fn
      # TODO: remove this
      # local[at!: delta] = value
      {:=, _meta,
       [
         {{:., _, [Access, :get]}, _,
          [
            {local, _, nil},
            [
              at!: delta
            ]
          ]},
         value
       ]}
      when is_atom(local) and is_map_key(locals, local) ->
        quote do
          Orb.Memory.store!(
            unquote(locals[local]),
            Instruction.local_get(unquote(locals[local]), unquote(local)),
            unquote(value)
          )
          |> Orb.Memory.Store.offset_by(unquote(delta))
        end

      # Setting variable
      {:=, _, [left, right]} = quoted ->
        do_match(left, right, locals) || quoted

      # Getting variable
      {local, _meta, nil} when is_atom(local) and is_map_key(locals, local) ->
        quote do: Orb.VariableReference.local(unquote(local), unquote(locals[local]))

      # e.g. `_ = some_function_returning_value()`
      {:=, _, [{:_, _, nil}, value]} ->
        quote do: Orb.Stack.Drop.new(unquote(value))

      other ->
        other
    end)
  end

  # TODO: remove
  def export(f = %Orb.Func{}, name) when is_binary(name) do
    update_in(f.exported_names, fn names -> [name | names] end)
  end

  def i32(n) when is_integer(n), do: Instruction.i32(:const, n)

  # TODO: should either commit to this idea (with a unit test) or remove it.
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
  def f32(n) when is_float(n), do: Instruction.f32(:const, n)
  def f64(n) when is_float(n), do: Instruction.f64(:const, n)

  def __expand_identifier(identifier, env) do
    identifier = Macro.expand_once(identifier, env) |> Kernel.to_string()

    case identifier do
      "Elixir." <> _rest = string ->
        string |> Module.split() |> Enum.join(".")

      other ->
        other
    end
  end

  def local(locals) do
    # %{locals: locals}
    Orb.InstructionSequence.new(nil, [], locals: locals)
  end

  # defmacro local({:=, _meta, [a, b]}) do
  #   # dbg(arg)

  #   quote do
  #     # nil
  #     var!(unquote(a)) = nil
  #   end
  # end

  @doc """
  Declare a loop that iterates through an Orb.Iterator or Elixir.Range.

  ```elixir
  sum = 0
  loop i <- 1..10 do
    sum = sum + i
  end
  ```

  ```elixir
  sum = 0
  loop _ <- 1..10 do
    sum = sum + 1
  end
  ```

  ```elixir
  sum = 0
  loop char <- alphabet do
    sum = sum + 1
  end
  ```

  ```elixir
  sum = 0
  loop char <- alphabet do
    sum = sum + char
  end
  ```

  ```elixir
  sum = 0
  loop _ <- alphabet do
    sum = sum + 1
  end
  ```
  """
  defmacro loop({:<-, _, [{identifier, _, nil} = var, source]}, do: block)
           when is_atom(identifier) do
    quote bind_quoted: [
            source: source,
            init_elixir_var:
              case identifier do
                :_ ->
                  nil

                identifier ->
                  source_type =
                    quote do
                      case unquote(source) do
                        %Range{} ->
                          Orb.I32

                        %Orb.VariableReference{push_type: source_iterator} ->
                          source_iterator.value_type()
                      end
                    end

                  quote(
                    do:
                      var!(unquote(var)) =
                        Orb.VariableReference.local(unquote(identifier), unquote(source_type))
                  )
              end,
            identifier: identifier,
            block_items: __get_block_items(block)
          ] do
      case source do
        %Range{first: first, last: last, step: 1} ->
          with do
            element_type = Orb.I32
            _ = init_elixir_var

            Orb.InstructionSequence.new([
              Orb.Instruction.local_set(element_type, identifier, first),
              %Orb.Loop{
                identifier: identifier,
                body:
                  Orb.InstructionSequence.new(
                    List.flatten([
                      block_items,
                      Orb.Instruction.local_set(
                        element_type,
                        identifier,
                        Orb.Numeric.Add.optimized(
                          element_type,
                          Orb.Instruction.local_get(element_type, identifier),
                          1
                        )
                      ),
                      %Orb.Loop.Branch{
                        identifier: identifier,
                        if:
                          Orb.I32.le_u(
                            Orb.Instruction.local_get(element_type, identifier),
                            last
                          )
                      }
                    ])
                  )
              }
            ])
            |> Orb.InstructionSequence.concat_locals([{identifier, element_type}])
          end

        %Orb.VariableReference{push_type: source_iterator} = source ->
          with do
            element_type = source_iterator.value_type()
            _ = init_elixir_var

            body =
              Orb.IfElse.new(
                source_iterator.valid?(source),
                Orb.InstructionSequence.new(
                  List.flatten([
                    case identifier do
                      :_ ->
                        []

                      identifier ->
                        Orb.Instruction.local_set(
                          element_type,
                          identifier,
                          source_iterator.value(source)
                        )
                    end,
                    block_items,
                    Orb.VariableReference.set(source, source_iterator.next(source)),
                    %Orb.Loop.Branch{identifier: identifier}
                  ])
                )
              )

            Orb.InstructionSequence.new([
              %Orb.Loop{
                identifier: identifier,
                push_type: nil,
                body: body
              }
            ])
            |> Orb.InstructionSequence.concat_locals(
              case identifier do
                :_ ->
                  []

                identifier ->
                  [{identifier, element_type}]
              end
            )
          end
      end
    end
  end

  defmacro loop({:<-, meta, [_item, _source]}, do: _block) do
    env = __CALLER__

    raise CompileError,
      line: meta[:line],
      file: env.file,
      description: "Cannot iterate using existing local name."
  end

  @doc """
  Declare a loop.
  """
  defmacro loop(identifier, options \\ [], do: block) do
    env = __CALLER__
    identifier = __expand_identifier(identifier, env)

    result_type =
      Keyword.get(options, :result, nil) |> Macro.expand_literals(__CALLER__)

    while = Keyword.get(options, :while, nil)

    block_items = __get_block_items(block)

    # TODO: is there some way to do this using normal Elixir modules?
    # I think we can define a module inline.
    block_items =
      Macro.prewalk(block_items, fn
        {{:., _, [{:__aliases__, _, [identifier]}, :continue]}, _, []} ->
          quote do: %Orb.Loop.Branch{identifier: unquote(__expand_identifier(identifier, env))}

        {{:., _, [{:__aliases__, _, [identifier]}, :continue]}, _, [[if: condition]]} ->
          quote do: %Orb.Loop.Branch{
                  identifier: unquote(__expand_identifier(identifier, env)),
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
        push_type: unquote(result_type),
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

        Orb.InstructionSequence.new(unquote(__get_block_items(block)))
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

  @doc """
  Asserts multiple conditions that _must_ be true, otherwise traps with unreachable.
  """
  defmacro must!(do: block) do
    quote bind_quoted: [
            checks: __get_block_items(block)
          ] do
      Orb.IfElse.new(
        Orb.I32.eqz(Enum.reduce(checks, &Orb.I32.band/2)),
        unreachable!()
      )
    end
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
