defmodule Orb.DSL do
  alias Orb.Ops
  require Ops

  def expand_type(type, env \\ __ENV__) do
    Orb.ToWat.Instructions.expand_type(type, env)
  end

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

  # TODO: require `globals` option be passed to explicitly list global used.
  # Would be useful for sharing funcp between wasm modules too.
  # Also incentivises making funcp pure by having all inputs be parameters.
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

  defp define_func(call, visibility, options, block, env) do
    call = Macro.expand_once(call, __ENV__)

    {name, args} =
      case Macro.decompose_call(call) do
        :error -> {Orb.DSL.__expand_identifier(call, __ENV__), []}
        other -> other
      end

    name = name

    exported? =
      case visibility do
        :public -> true
        :private -> false
      end

    params =
      case args do
        [args] when is_list(args) ->
          for {name, type} <- args do
            Macro.escape(param(name, expand_type(type, env)))
          end

        args ->
          for {name, _meta, [type]} <- args do
            Macro.escape(param(name, expand_type(type, env)))
          end
      end

    arg_types =
      case args do
        [args] when is_list(args) ->
          for {name, type} <- args do
            {name, expand_type(type, env)}
          end

        args ->
          for {name, _meta, [type]} <- args do
            {name, expand_type(type, env)}
          end
      end

    result_type = Keyword.get(options, :result, nil) |> expand_type(env)

    local_types =
      for {key, type} <- Keyword.get(options, :locals, []) do
        {key, expand_type(type, env)}
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
      # List.flatten([
      #   unquote(Macro.escape(data_els)),
      %Orb.Func{
        name: unquote(name),
        params: unquote(params),
        result: case unquote(result_type) do
          nil -> nil
          type -> {:result, type}
        end,
        local_types: unquote(local_types),
        body: unquote(block_items),
        exported?: unquote(exported?)
      }

      # ])
    end
  end

  def do_snippet(locals, block_items) do
    Macro.prewalk(block_items, fn
      # TODO: remove, replace with I32.store8
      {:=, _, [{{:., _, [Access, :get]}, _, [{:memory32_8!, _, nil}, offset]}, value]} ->
        quote do: {:i32, :store8, unquote(offset), unquote(value)}

      {{:., _, [{{:., _, [Access, :get]}, _, [{:memory32_8!, _, nil}, offset]}, :unsigned]}, _, _} ->
        quote do: {:i32, :load8_u, unquote(offset)}

      # TODO: remove, replace with I32.store
      {:=, _, [{{:., _, [Access, :get]}, _, [{:memory32!, _, nil}, offset]}, value]} ->
        quote do: {:i32, :store, unquote(offset), unquote(value)}

      {{:., _, [Access, :get]}, _, [{:memory32!, _, nil}, offset]} ->
        quote do: {:i32, :load, unquote(offset)}

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

        computed_offset =
          case {offset, bytes_factor} do
            {0, _} ->
              quote do: local_get(unquote(local))

            {offset, 1} ->
              quote do: Orb.I32.add(local_get(unquote(local)), unquote(offset))

            # We can compute at compile-time
            {offset, factor} when is_integer(offset) ->
              quote do:
                      Orb.I32.add(
                        local_get(unquote(local)),
                        unquote(offset * factor)
                      )

            # We can only compute at runtime
            {offset, factor} ->
              quote do:
                      Orb.I32.add(
                        local_get(unquote(local)),
                        I32.mul(unquote(offset), unquote(factor))
                      )
          end

        quote do: {:i32, unquote(store_instruction), unquote(computed_offset), unquote(value)}

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

  # TODO: merge with existing code?
  @primitive_types [:i32, :f32, :i32_u8]

  defp param(name, type) when type in @primitive_types do
    %Orb.Func.Param{name: name, type: type}
  end

  defp param(name, type) when is_atom(type) do
    # unless function_exported?(type, :wasm_type, 0) do
    #   raise "Param of type #{type} must implement wasm_type/0."
    # end

    %Orb.Func.Param{name: name, type: type}
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

  def push(n) when is_integer(n), do: {:i32_const, n}
  def push(%Orb.VariableReference{} = ref), do: ref

  def push(do: [value, {:local_set, local}]), do: [value, {:local_tee, local}]

  @doc """
  Push value then run the block. Useful for when you mutate a variable but want its previous value.
  """
  def push(value, do: block) do
    [
      value,
      __get_block_items(block),
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

  defmacro attr_writer(global_name) when is_atom(global_name) do
    quote do
      func unquote(String.to_atom("#{global_name}="))(new_value: I32) do
        local_get(:new_value)
        global_set(unquote(global_name))
      end
    end
  end

  defmacro attr_writer(global_name, as: func_name)
           when is_atom(global_name) |> Kernel.and(is_atom(func_name)) do
    quote do
      func unquote(func_name)(new_value: I32) do
        local_get(:new_value)
        global_set(unquote(global_name))
      end
    end
  end

  @doc """
  Call local function `f`.
  """
  def call(f), do: {:call, f, []}

  @doc """
  Call local function `f`, passing single argument `a`.
  """
  def call(f, a), do: {:call, f, [a]}
  @doc """
  Call local function `f`, passing arguments `a` & `b`.
  """
  def call(f, a, b), do: {:call, f, [a, b]}
  @doc """
  Call local function `f`, passing argument `a`, `b` & `c`.
  """
  def call(f, a, b, c), do: {:call, f, [a, b, c]}

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
    result_type = Keyword.get(options, :result, nil) |> Orb.ToWat.Instructions.expand_type(__CALLER__)
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
  defmacro defblock(identifier, options \\ [], do: block) do
    identifier = __expand_identifier(identifier, __CALLER__)
    result_type = Keyword.get(options, :result, nil) |> Orb.ToWat.Instructions.expand_type(__CALLER__)

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
    block |> __get_block_items()
  end

  @doc """
  Run Elixir for-comprehension at compile-time.
  """
  defmacro inline({:for, meta, [for_arg]}, do: block) do
    # for_arg = interpolate_external_values(for_arg, __CALLER__)
    block = block |> __get_block_items()
    # import Kernel
    {:for, meta, [for_arg, [do: block]]}
    # {:for, meta, [for_arg, [do: quote do: inline(do: unquote(block))]]}
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
