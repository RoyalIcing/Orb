defmodule Orb.DSL do
  @moduledoc """
  The main DSL which is imported automatically when you call `Orb.wasm/2`.
  """

  alias Orb.Instruction
  alias Orb.Ops
  require Ops

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
    Orb.Func.Type.imported_func(name, options[:params], options[:result])
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
    {_, meta, _} = call

    {name, args} =
      case Macro.decompose_call(call) do
        :error -> {Orb.DSL.__expand_identifier(call, __ENV__), []}
        other -> other
      end

    name = name

    exported_names =
      case visibility do
        :public -> quote do: [to_string(unquote(name))]
        :private -> []
      end

    params =
      case args do
        [args] when is_list(args) ->
          for {name, type} <- args do
            Macro.escape(%Orb.Func.Param{name: name, type: Macro.expand_literals(type, env)})
          end

        [] ->
          []

        [_ | _] ->
          raise CompileError,
            line: meta[:line],
            file: env.file,
            description:
              "Cannot define function with multiple arguments, use keyword list instead."
      end

    arg_types =
      case args do
        [args] when is_list(args) ->
          for {name, type} <- args do
            {name, Macro.expand_literals(type, env)}
          end

        args ->
          for {name, _meta, [type]} <- args do
            {name, Macro.expand_literals(type, env)}
          end
      end

    result_type = Keyword.get(options, :result, nil) |> Macro.expand_literals(env)

    local_types =
      for {key, type} <- Keyword.get(options, :locals, []) do
        {key, Macro.expand_literals(type, env)}
      end

    locals = Map.new(arg_types ++ local_types)

    # block = Macro.expand_once(block, __ENV__)

    block_items =
      case block do
        {:__block__, _meta, block_items} -> block_items
        single -> [single]
      end

    block_items = Macro.expand(block_items, env)
    block_items = do_snippet(locals, block_items)

    quote do
      %Orb.Func{
        name: unquote(name),
        params: unquote(params),
        result: unquote(result_type),
        local_types: unquote(local_types),
        body: unquote(block_items),
        # body: fn ->
        #   if Process.get(Orb.DSL, false) do
        #     unquote(block_items)
        #   else
        #     []
        #   end
        # end,
        exported_names: unquote(exported_names)
      }
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
                Orb.Instruction.i32(
                  unquote(store_instruction),
                  unquote(computed_offset),
                  unquote(value)
                )

      {:=, _, [{local, _, nil}, input]}
      when is_atom(local) and is_map_key(locals, local) and
             is_struct(:erlang.map_get(local, locals), Orb.VariableReference) ->
        [input, quote(do: {:local_set, unquote(local)})]

      {:=, _, [{local, _, nil}, input]}
      when is_atom(local) and is_map_key(locals, local) ->
        [input, quote(do: {:local_set, unquote(local)})]

      {atom, _meta, nil} when is_atom(atom) and is_map_key(locals, atom) ->
        # {:local_get, meta, [atom]}
        quote do: Orb.VariableReference.local(unquote(atom), unquote(locals[atom]))

      # @some_global = input
      {:=, _, [{:@, _, [{global, _, nil}]}, input]} when is_atom(global) ->
        [input, Orb.DSL.global_set(global)]

      # @some_global
      #       node = {:@, meta, [{global, _, nil}]} when is_atom(global) ->
      #         if global == :weekdays_i32 do
      #           dbg(meta)
      #           dbg(node)
      #         end
      #
      #         {:global_get, meta, [global]}

      {:=, _, [{:_, _, nil}, value]} ->
        quote do: [unquote(value), :drop]

      other ->
        other
    end)
  end

  def export(f = %Orb.Func{}, name) when is_binary(name) do
    update_in(f.exported_names, fn names -> [name | names] end)
  end

  # TODO: unused
  def i32_const(value), do: {:i32_const, value}
  def i32_boolean(0), do: {:i32_const, 0}
  def i32_boolean(1), do: {:i32_const, 1}
  def i32(n) when is_integer(n), do: {:i32_const, n}
  def i32(false), do: {:i32_const, 0}
  def i32(true), do: {:i32_const, 1}
  def i32(op) when op in Ops.i32(:all), do: {:i32, op}

  @doc """
  Pushes a value onto the current stack.
  """
  def push(value)

  def push(tuple)
      when is_tuple(tuple) and elem(tuple, 0) in [:i32, :i32_const, :local_get, :global_get],
      do: tuple

  # FIXME: assumes only 32-bit integer, doesn’t work with 64-bit or float
  def push(n) when is_integer(n), do: {:i32_const, n}
  # FIXME: assumes only 32-bit float, doesn’t work with 64-bit float
  def push(n) when is_float(n), do: {:f32_const, n}
  def push(%Orb.VariableReference{} = ref), do: ref

  def push(do: [value, {:local_set, local}]), do: [value, {:local_tee, local}]

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

  def global_get(identifier), do: {:global_get, identifier}
  def global_set(identifier), do: {:global_set, identifier}

  def local(identifier, type), do: {:local, identifier, type}
  def local_get(identifier), do: {:local_get, identifier}
  def local_set(identifier), do: {:local_set, identifier}
  # TODO: use local_tee when using push(local = …)
  def local_tee(identifier), do: {:local_tee, identifier}
  def local_tee(identifier, value), do: [value, {:local_tee, identifier}]

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
  defmacro loop({:<-, _, [item, source]}, do: block) do
    result_type = nil

    {set_item, identifier} =
      case item do
        {:_, _, _} ->
          {[], "_"}

        _ ->
          {quote(
             do: [
               unquote(source)[:value],
               Orb.VariableReference.as_set(unquote(item))
             ]
           ), quote(do: unquote(item).identifier)}
      end

    block_items =
      quote(
        do:
          Orb.IfElse.new(
            # unquote(source),
            unquote(source)[:valid?],
            [
              unquote(set_item),
              unquote(__get_block_items(block)),
              unquote(source)[:next],
              Orb.VariableReference.as_set(unquote(source)),
              {:br, unquote(identifier)}
            ]
          )
      )

    quote do
      %Orb.Loop{
        identifier: unquote(identifier),
        result: unquote(result_type),
        body: unquote(block_items)
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

    block_items =
      Macro.prewalk(block_items, fn
        {{:., _, [{:__aliases__, _, [identifier]}, :continue]}, _, []} ->
          # quote do: br(unquote(identifier))
          quote do: {:br, unquote(identifier)}

        {{:., _, [{:__aliases__, _, [identifier]}, :continue]}, _, [[if: condition]]} ->
          # quote do: br(unquote(identifier))
          quote do: {:br_if, unquote(identifier), unquote(condition)}

        other ->
          other
      end)

    block_items =
      case while do
        nil ->
          block_items

        condition ->
          quote do:
                  Orb.IfElse.new(
                    unquote(condition),
                    [unquote(block_items), {:br, unquote(identifier)}]
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
  Declare a block, useful for structured control flow.
  """
  defmacro block(identifier, result_type \\ nil, do: block) do
    identifier = __expand_identifier(identifier, __CALLER__)
    result_type = Macro.expand_literals(result_type, __CALLER__)
    block_items = __get_block_items(block)

    quote do
      %Orb.Block{
        identifier: unquote(identifier),
        result: unquote(result_type),
        body: unquote(block_items)
      }
    end
  end

  # import Kernel

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
  defmacro wasm(mode \\ Orb.S32, do: block) do
    mode = Macro.expand_literals(mode, __CALLER__)
    pre = Orb.__mode_pre(mode)

    quote do
      with do
        unquote(pre)
        import Orb, only: []
        import Orb.DSL

        unquote(__get_block_items(block))
      end
    end
  end

  @doc """
  Declare a constant string, which will be extracted to the top of the module, and its address substituted in place.
  """
  def const(value) do
    {:const_string, value}
  end

  # TODO: decide if this idea is dead.
  @doc false
  def const_set_insert(set_name, string) when is_atom(set_name) and is_binary(string) do
    :todo
  end

  # TODO: add a comptime keyword like Zig: https://kristoff.it/blog/what-is-zig-comptime/

  @doc """
  Break from a block.
  """
  def break(identifier), do: {:br, __expand_identifier(identifier, __ENV__)}

  @doc """
  Break from a block if a condition is true.
  """
  def break(identifier, if: condition),
    do: {:br_if, __expand_identifier(identifier, __ENV__), condition}

  @doc """
  Return from a function. You may wish to `push/1` values before returning.
  """
  def return(), do: :return

  @doc """
  Return from a function if a condition is true.
  """
  def return(value_or_condition)

  def return(if: condition), do: Orb.IfElse.new(condition, :return)
  def return(value), do: {:return, value}

  @doc """
  Return from a function with the provided value only if a condition is true.
  """
  def return(value, if: condition), do: Orb.IfElse.new(condition, {:return, value})

  @doc """
  A no-op instruction.

  See https://en.wikipedia.org/wiki/NOP_(code)
  """
  def nop(), do: :nop

  @doc """
  Drop the last pushed value from the stack.
  """
  def drop(), do: :drop

  @doc """
  Execute the passed expression, but ignore its result by immediately dropping its value.
  """
  def drop(expression), do: [expression, :drop]

  @doc """
  Denote a point in code that should not be reachable. Traps.

  Useful for exhaustive conditionals or code you know will not execute.
  """
  def unreachable!(), do: :unreachable

  @doc """
  Asserts a condition that _must_ be true, otherwise traps.
  """
  def assert!(condition) do
    Orb.IfElse.new(
      condition,
      nop(),
      unreachable!()
    )
  end

  def mut!(term), do: Orb.MutRef.from(term)

  @doc """
  For when there’s a language feature of WebAssembly that Orb doesn’t provide. Please file an issue if there’s something you wish existed. https://github.com/RoyalIcing/Orb/issues
  """
  def raw_wat(source), do: {:raw_wat, String.trim(source)}

  def __get_block_items(block) do
    case block do
      nil -> nil
      {:__block__, _meta, block_items} -> block_items
      single -> [single]
    end
  end
end
