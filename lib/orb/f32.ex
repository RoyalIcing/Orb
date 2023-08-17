defmodule Orb.F32 do
  @moduledoc false

  require Orb.Ops, as: Ops
  alias Orb.Instruction

  @behaviour Orb.CustomType

  @impl Orb.CustomType
  def wasm_type(), do: :f32

  @impl Orb.CustomType
  def byte_count(), do: 4

  for op <- Ops.f32(1) do
    def unquote(op)(a) do
      Instruction.f32(unquote(op), a)
    end
  end

  for op <- Ops.f32(2) do
    def unquote(op)(a, b) do
      Instruction.f32(unquote(op), a, b)
    end
  end

  defmacro global(mutability \\ :mutable, list)
           when mutability in ~w{readonly mutable}a do
    quote do
      @wasm_globals (for {key, value} <- unquote(list) do
                       Orb.Global.new(
                         :f32,
                         key,
                         unquote(mutability),
                         :internal,
                         {:f32_const, value}
                       )
                     end)
    end
  end

  defmacro export_global(mutability, list)
           when mutability in ~w{readonly mutable}a do
    quote do
      @wasm_globals (for {key, value} <- unquote(list) do
                       Orb.Global.new(
                         :f32,
                         key,
                         unquote(mutability),
                         :exported,
                         {:f32_const, value}
                       )
                     end)
    end
  end

  defmodule DSL do
    @moduledoc """
    32-bit float operators.
    """

    import Kernel, except: [+: 2, -: 2, *: 2, ===: 2, !==: 2, /: 2, <=: 2, >=: 2]

    def left + right do
      Instruction.f32(:add, left, right)
    end

    def left - right do
      Instruction.f32(:sub, left, right)
    end

    def left * right do
      Instruction.f32(:mul, left, right)
    end

    def left / right do
      Instruction.f32(:div, left, right)
    end

    def _left == _right do
      raise "== is not supported in Orb. Use === instead."
    end

    def _left != _right do
      raise "!= is not supported in Orb. Use !== instead."
    end

    def left === right do
      Instruction.f32(:eq, left, right)
    end

    def left !== right do
      Instruction.f32(:ne, left, right)
    end

    def left < right do
      Instruction.f32(:lt, left, right)
    end

    def left > right do
      Instruction.f32(:gt, left, right)
    end

    def left <= right do
      Instruction.f32(:le, left, right)
    end

    def left >= right do
      Instruction.f32(:ge, left, right)
    end
  end
end
