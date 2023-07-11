defmodule Orb.I32.String do
  # TODO: should this be called I32.ASCII?

  @behaviour Orb.Type
  @behaviour Access

  @impl Orb.Type
  def wasm_type(), do: :i32

  # TODO: is the byte count of the pointer, or the items?
  @impl Orb.Type
  def byte_count(), do: 1

  @impl Access
  def fetch(%Orb.VariableReference{} = var_ref, at!: offset) do
    ast = {:i32, :load8_u, Orb.I32.Add.neutralize(var_ref, offset)}
    {:ok, ast}
  end

  defmodule CharIterator do
    @behaviour Orb.Type
    @impl Orb.Type
    def wasm_type(), do: :i32

    @behaviour Access

    @impl Access
    def fetch(%Orb.VariableReference{} = var_ref, :value) do
      {:ok, {:i32, :load8_u, var_ref}}
    end

    def fetch(%Orb.VariableReference{} = var_ref, :next) do
      require Orb
      require Orb.I32

      ast =
        Orb.snippet do
          Orb.I32.when? {:i32, :load8_u, Orb.I32.Add.neutralize(var_ref, 1)} do
            Orb.I32.Add.neutralize(var_ref, 1)
          else
            0x0
          end
        end

      {:ok, ast}
    end
  end

  use Orb

  wasm_memory(pages: 1)

  wasm do
    func streq(address_a: I32, address_b: I32),
         I32,
         i: I32,
         byte_a: I32,
         byte_b: I32 do
      loop EachByte, result: I32 do
        byte_a = memory32_8![I32.add(address_a, i)].unsigned
        byte_b = memory32_8![I32.add(address_b, i)].unsigned

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

    func strlen(string_ptr: I32.String), I32, count: I32 do
      # while (string_ptr[count] != 0) {
      #   count++;
      # }

      # loop EachChar, while: memory32_8![count] do

      loop EachChar do
        if memory32_8![I32.add(string_ptr, count)].unsigned do
          count = I32.add(count, 1)
          EachChar.continue()
        end
      end

      count
    end
  end

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [streq: 2, strlen: 1]

      import Orb

      Orb.wasm do
        unquote(__MODULE__).funcp()
        # unquote(__MODULE__).funcp(:streq)
        # unquote(__MODULE__).funcp(:strlen)
      end
    end
  end

  # TODO: is it safe to call this empty() ?
  def null(), do: {:i32_const, 0}

  def streq(address_a, address_b), do: call(:streq, address_a, address_b)
  def strlen(string_ptr), do: call(:strlen, string_ptr)

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
                [unquote(Orb.__get_block_items(target)), break(:i32_string_match)]
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
      defblock :i32_string_match, result: I32 do
        unquote(statements)
        unquote(final_instruction)
      end
    end
  end
end
