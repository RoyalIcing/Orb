defmodule Orb.I32.String do
  @moduledoc """
  Custom type for a nul-terminated ASCII string.
  """

  # TODO: should this be called Orb.I32.ASCII? Or just Orb.ASCII?

  @behaviour Orb.CustomType
  @behaviour Access

  @impl Orb.CustomType
  def wasm_type(), do: :i32

  # TODO: is the byte count of the pointer, or the items?
  @impl Orb.CustomType
  def byte_count(), do: 1

  @impl Access
  def fetch(%Orb.VariableReference{} = var_ref, at!: offset) do
    # ast = Orb.Instruction.i32(:load8_u, Orb.Numeric.Add.optimized(Orb.I32, var_ref, offset))
    ast = Orb.Memory.load!(Orb.I32.U8, Orb.Numeric.Add.optimized(Orb.I32, var_ref, offset))
    {:ok, ast}
  end

  @impl Access
  def get_and_update(_data, _key, _function) do
    raise UndefinedFunctionError, module: __MODULE__, function: :get_and_update, arity: 3
  end

  @impl Access
  def pop(_data, _key) do
    raise UndefinedFunctionError, module: __MODULE__, function: :pop, arity: 2
  end

  use Orb

  Memory.pages(1)

  # TODO: remove all of these funcs. It will live in SilverOrb instead.
  # Plus strings will likely become a Memory.Range instead, so we know the length statically.
  defw streq(address_a: I32, address_b: I32),
       I32,
       i: I32,
       byte_a: I32,
       byte_b: I32 do
    loop EachByte, result: I32 do
      byte_a = Memory.load!(I32.U8, I32.add(address_a, i))
      byte_b = Memory.load!(I32.U8, I32.add(address_b, i))

      # I32.match byte_a do
      #   0 ->
      #     return(byte_b === 0)

      #   byte_b ->
      #     i = i + 1
      #     EachByte.continue()

      #   _ ->
      #     return(0x0)
      # end

      if I32.eqz(byte_a) do
        return(I32.eqz(byte_b))
      end

      if I32.eq(byte_a, byte_b) do
        i = I32.add(i, 1)
        EachByte.continue()
      end

      return(0x0)
    end
  end

  defw strlen(string_ptr: I32.String), I32, count: I32 do
    # while (string_ptr[count] != 0) {
    #   count++;
    # }

    # loop EachChar, while: memory32_8![count] do

    loop EachChar do
      if Memory.load!(I32.U8, I32.add(string_ptr, count)) do
        # FIXME: remove memory32_8!
        # if Memory.load!(I32.U8, I32.add(string_ptr, count)) do
        count = I32.add(count, 1)
        EachChar.continue()
      end
    end

    count
  end

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [streq: 2, strlen: 1]

      import Orb

      Orb.include(unquote(__MODULE__))
    end
  end

  # TODO: is it safe to call this empty() ?
  def null(), do: {:i32_const, 0}

  def streq(address_a, address_b), do: Orb.DSL.typed_call(I32, :streq, [address_a, address_b])
  def strlen(string_ptr), do: Orb.DSL.typed_call(I32, :strlen, [string_ptr])

  defmacro match(value, do: transform) do
    statements =
      for {:->, _, [input, target]} <- transform do
        case input do
          # _ ->
          # like an else clause
          [{:_, _, _}] ->
            quote do
              unquote(Orb.__get_block_items(target))
            end

          [match] ->
            quote do
              Orb.IfElse.new(
                streq(unquote(value), unquote(match)),
                [unquote(Orb.__get_block_items(target)), Orb.Control.break(:i32_string_match)]
              )
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
      Orb.Control.block :i32_string_match, I32 do
        unquote(statements)
        unquote(final_instruction)
      end
    end
  end
end
