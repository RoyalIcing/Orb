defmodule DefwTest do
  use ExUnit.Case, async: true

  defmacrop location(plus) do
    caller = __CALLER__
    file = Path.relative_to_cwd(caller.file)
    quote do: "#{unquote(file)}:#{unquote(caller.line) + unquote(plus)}"
  end

  defmacrop module_wat(do: block) do
    location = Macro.Env.location(__CALLER__)

    {:module, mod, _, _} =
      Module.create(
        String.to_atom("Elixir.Sample#{location[:line]}"),
        block,
        location
      )

    quote do
      unquote(mod).to_wat()
    end
  end

  defmodule AddI32 do
    use Orb

    defw add(first: I32, second: I32) do
      first + second
    end
  end

  test "i32 mode by default" do
    assert AddI32.to_wat() =~ "(i32.add (local.get $first) (local.get $second))"
  end

  test "reads f32 mode" do
    assert (module_wat do
              use Orb

              # @wasm_mode Orb.F32
              wasm_mode Orb.F32

              defw add(first: I32, second: I32) do
                first + second
              end
            end) =~ "(f32.add (local.get $first) (local.get $second))"
  end

  test "restore i32 mode" do
    assert (module_wat do
              use Orb

              wasm_mode Orb.F32

              defw add_f32(f1: F32, f2: F32) do
                f1 + f2
              end

              wasm_mode Orb.S32

              defw add_i32(i1: I32, i2: I32) do
                i1 + i2
              end
            end) =~ "(i32.add (local.get $i1) (local.get $i2))"
  end

  test "multiple args errs" do
    assert_raise CompileError,
                 ~r[#{location(+5)}: Cannot define function with multiple arguments, use keyword list instead.],
                 fn ->
                   defmodule Sample do
                     use Orb

                     defw add(first, second) do
                       3
                     end
                   end
                 end
  end
end
