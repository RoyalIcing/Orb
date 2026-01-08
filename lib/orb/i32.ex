defmodule Orb.I32 do
  @moduledoc """
  Type for 32-bit integer.
  """

  import Kernel, except: [and: 2, or: 2]

  alias require Orb.Ops
  alias Orb.Instruction
  alias Orb.InstructionSequence

  with @behaviour Orb.CustomType do
    @impl Orb.CustomType
    def wasm_type, do: :i32
  end

  def const(n) when is_integer(n), do: Instruction.Const.wrap(:i32, n)

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
      Instruction.i32(unquote(op), a)
    end
  end

  for op <- Ops.i32(2) do
    case op do
      :eq ->
        # TODO: is this the best place for this optimization?
        # Perhaps it should be done at `def a === b`
        # Otherwise it would justify adding optimization for `0 AND 1 --> 0` etc too.
        def eq(0, n), do: Instruction.i32(:eqz, n)
        def eq(n, 0), do: Instruction.i32(:eqz, n)
        def eq(a, b), do: Instruction.i32(:eq, a, b)

      :and ->
        def band(a, b) do
          Instruction.i32(:and, a, b)
        end

      _ ->
        def unquote(op)(a, b) do
          Instruction.i32(unquote(op), a, b)
        end
    end
  end

  def sum!([]), do: const(0)

  def sum!(items) when is_list(items) do
    items
    |> Enum.map(&Orb.TypeNarrowable.type_narrow_to(&1, __MODULE__))
    |> Enum.reduce(&add/2)
  end

  def in?(value, list) when is_list(list) do
    instructions =
      for {item, index} <- Enum.with_index(list) do
        case index do
          0 ->
            eq(value, item)

          _ ->
            # InstructionSequence.new(:i32, [eq(value, item), Instruction.i32(:or)])
            Instruction.i32(:or, eq(value, item))
        end
      end

    InstructionSequence.new(:i32, instructions)
  end

  @doc "Converts an ASCII little-endian 4-byte string to an 32-bit integer."
  def from_4_byte_ascii(<<int::little-size(32)>>), do: int
  # def to_4_byte_ascii(i32) when is_integer(i32), do: <<i32::little-size(32)>>

  defmacro match(value, do: transform) do
    statements =
      for {:->, _, [input, result]} <- transform do
        case input do
          # _ ->
          # like an else clause
          [{:_, _, _}] ->
            quote do: Orb.InstructionSequence.new(unquote(__get_block_items(result)))

          [match] ->
            quote do
              Orb.IfElse.new(
                nil,
                Orb.I32.eq(unquote(value), unquote(match)),
                Orb.InstructionSequence.new(
                  :i32,
                  unquote(__get_block_items(result)) ++ [Orb.Control.break(:i32_match)]
                ),
                nil
              )
            end

          matches ->
            quote do
              Orb.IfElse.new(
                nil,
                Orb.I32.in?(unquote(value), unquote(matches)),
                Orb.InstructionSequence.new(
                  :i32,
                  unquote(__get_block_items(result)) ++ [Orb.Control.break(:i32_match)]
                ),
                nil
              )
            end
        end
      end

    has_catchall? = Enum.any?(transform, &match?({:->, _, [[{:_, _, _}], _]}, &1))

    final_instruction =
      case has_catchall? do
        false -> quote do: %Orb.Unreachable{debug_reason: "Orb.I32.match/2 catchall"}
        true -> quote do: Orb.InstructionSequence.empty()
      end

    quote do
      with do
        require Orb.Control

        Orb.Control.block :i32_match, Orb.I32 do
          Orb.InstructionSequence.new(nil, unquote(statements))
          unquote(final_instruction)
        end
      end
    end
  end

  defmacro cond(do: transform) do
    line = __CALLER__.line
    block_name = "i32_cond_#{line}"

    statements =
      for {:->, _, [input, target]} <- transform do
        case input do
          # true ->
          # like an else clause
          [true] ->
            target

          [match] ->
            quote do
              Orb.IfElse.new(
                unquote(match),
                Orb.InstructionSequence.new(
                  unquote(__get_block_items(target)) ++ [Orb.Control.break(unquote(block_name))]
                )
              )
            end
        end
      end

    has_catchall? = Enum.any?(transform, &match?({:->, _, [[true], _]}, &1))

    final_instruction =
      case has_catchall? do
        false -> quote do: %Orb.Unreachable{debug_reason: "Orb.I32.cond/1 catchall"}
        true -> quote do: Orb.InstructionSequence.empty()
      end

    quote do
      with do
        require Orb.Control

        Orb.Control.block unquote(block_name), Orb.I32 do
          Orb.InstructionSequence.new(unquote(statements))
          unquote(final_instruction)
        end
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

  def __global_value(value) when is_integer(value), do: const(value)
  def __global_value(false), do: const(0)
  def __global_value(true), do: const(1)
  # TODO: stash away which module so we can do smart stuff like with local types
  def __global_value(mod) when is_atom(mod),
    do: const(mod.initial_i32())

  # TODO: remove
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

  # TODO: remove
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
end
