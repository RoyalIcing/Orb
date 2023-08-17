defmodule Orb.I32 do
  @moduledoc """
  Type for 32-bit integer.
  """

  import Kernel, except: [and: 2, or: 2]

  alias Orb.Ops
  require Ops

  def wasm_type(), do: :i32

  def add(a, b)
  def sub(a, b)
  def mul(a, b)
  def div_u(a, divisor)
  def div_s(a, divisor)
  def rem_u(a, divisor)
  def rem_s(a, divisor)
  def unquote(:or)(a, b)
  def xor(a, b)
  def shl(a, b)
  def shr_u(a, b)
  def shr_s(a, b)
  def rotl(a, b)
  def rotr(a, b)

  for op <- Ops.i32(1) do
    def unquote(op)(a) do
      {:i32, unquote(op), a}
    end
  end

  for op <- Ops.i32(2) do
    case op do
      :eq ->
        def eq(0, n), do: {:i32, :eqz, n}
        def eq(n, 0), do: {:i32, :eqz, n}
        def eq(a, b), do: {:i32, :eq, {a, b}}

      :and ->
        def band(a, b) do
          {:i32, :and, {a, b}}
        end

      _ ->
        def unquote(op)(a, b) do
          {:i32, unquote(op), {a, b}}
        end
    end
  end

  def sum!(items) when is_list(items) do
    Enum.reduce(items, &add/2)
  end

  def in?(value, list) when is_list(list) do
    for {item, index} <- Enum.with_index(list) do
      case index do
        0 ->
          eq(value, item)

        _ ->
          [eq(value, item), {:i32, :or}]
      end
    end
  end

  defmacro when?(condition, do: when_true, else: when_false) do
    quote do
      Orb.IfElse.new(
        :i32,
        unquote(condition),
        unquote(__get_block_items(when_true)),
        unquote(__get_block_items(when_false))
      )
    end
  end

  # This only works with WebAssembly 1.1
  # Sadly wat2wasm doesn’t like it
  def select(condition, do: when_true, else: when_false) do
    [
      when_true,
      when_false,
      condition,
      :select
    ]
  end

  @doc "Converts an ASCII little-endian 4-byte string to an 32-bit integer."
  def from_4_byte_ascii(<<int::little-size(32)>>), do: int

  defmacro match(value, do: transform) do
    statements =
      for {:->, _, [input, result]} <- transform do
        case input do
          # _ ->
          # like an else clause
          [{:_, _, _}] ->
            __get_block_items(result)

          [match] ->
            quote do
              %Orb.IfElse{
                condition: I32.eq(unquote(value), unquote(match)),
                when_true: [unquote(__get_block_items(result)), break(:i32_match)]
              }
            end

          matches ->
            quote do
              %Orb.IfElse{
                condition: I32.in?(unquote(value), unquote(matches)),
                when_true: [unquote(__get_block_items(result)), break(:i32_match)]
              }
            end
        end
      end

    # catchall = for {:->, _, [[{:_, _, _}], _]} <- transform, do: true
    has_catchall? = Enum.any?(transform, &match?({:->, _, [[{:_, _, _}], _]}, &1))

    final_instruction =
      case has_catchall? do
        false -> :unreachable
        true -> []
      end

    quote do
      defblock :i32_match, result: I32 do
        unquote(statements)
        unquote(final_instruction)
      end
    end
  end

  defmacro cond(do: transform) do
    statements =
      for {:->, _, [input, target]} <- transform do
        case input do
          # true ->
          # like an else clause
          [true] ->
            target

          [match] ->
            quote do
              %Orb.IfElse{
                condition: unquote(match),
                when_true: [unquote(__get_block_items(target)), break(:i32_map)]
              }
            end
        end
      end

    catchall = for {:->, _, [[true], _]} <- transform, do: true

    final_instruction =
      case catchall do
        [] -> :unreachable
        [true] -> []
      end

    quote do
      defblock :i32_map, result: I32 do
        unquote(statements)
        unquote(final_instruction)
      end
    end
  end

  defp __get_block_items(block) do
    case block do
      nil -> nil
      {:__block__, _meta, block_items} -> block_items
      single -> [single]
    end
  end

  def __global_value(value) when is_integer(value), do: Orb.DSL.i32(value)
  def __global_value(false), do: Orb.DSL.i32(false)
  def __global_value(true), do: Orb.DSL.i32(true)
  # TODO: stash away which module so we can do smart stuff like with local types
  def __global_value(mod) when is_atom(mod), do: mod.initial_i32() |> Orb.DSL.i32()

  defmacro global(mutability \\ :mutable, list)
           when mutability in ~w{readonly mutable}a do
    quote do
      @wasm_globals (for {key, value} <- unquote(list) do
                       Orb.Global.new(
                         :i32,
                         key,
                         unquote(mutability),
                         :internal,
                         Orb.I32.__global_value(value)
                       )
                     end)
    end
  end

  defmacro export_global(mutability, list)
           when mutability in ~w{readonly mutable}a do
    quote do
      @wasm_globals (for {key, value} <- unquote(list) do
                       Orb.Global.new(
                         :i32,
                         key,
                         unquote(mutability),
                         :exported,
                         Orb.I32.__global_value(value)
                       )
                     end)
    end
  end

  defmacro export_enum(keys, offset \\ 0) do
    quote do
      unquote(__MODULE__).export_global(
        :readonly,
        Enum.with_index(unquote(keys), unquote(offset))
      )
    end
  end

  defmacro enum(keys, offset \\ 0) do
    quote do
      unquote(__MODULE__).global(:readonly, Enum.with_index(unquote(keys), unquote(offset)))
    end
  end

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
end
