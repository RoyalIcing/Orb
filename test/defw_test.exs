defmodule DefwTest do
  use ExUnit.Case, async: true
  alias OrbWasmtime.Instance

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
              wasm_mode(Orb.F32)

              defw add(first: I32, second: I32) do
                first + second
              end
            end) =~ "(f32.add (local.get $first) (local.get $second))"
  end

  test "restore i32 mode" do
    assert (module_wat do
              use Orb

              wasm_mode(Orb.F32)

              defw add_f32(f1: F32, f2: F32) do
                f1 + f2
              end

              wasm_mode(Orb.S32)

              defw add_i32(i1: I32, i2: I32) do
                i1 + i2
              end
            end) =~ "(i32.add (local.get $i1) (local.get $i2))"
  end

  test "globals work" do
    assert (module_wat do
              use Orb

              I32.enum([:component_l, :component_a, :component_b], 1)
              I32.export_global(:mutable, last_changed_component: 0)

              defw l_changed(new_value: F32) do
                @last_changed_component = @component_l
              end
            end) =~ """
               (global.get $component_l)
               (global.set $last_changed_component)
           """
  end

  defmodule Visibilities do
    use Orb

    defw first() do
      1
      :drop
    end

    defwi second() do
      2
      :drop
    end

    defwp third() do
      3
      :drop
    end
  end

  test "defwi does not export from wasm but makes a public Elixir function" do
    assert Visibilities.to_wat() =~ """
             (func $first (export "first")
               (i32.const 1)
               drop
             )
             (func $second
               (i32.const 2)
               drop
             )
             (func $third
               (i32.const 3)
               drop
             )
           """

    assert {:first, 0} in Visibilities.__info__(:functions)
    assert {:second, 0} in Visibilities.__info__(:functions)
    refute {:third, 0} in Visibilities.__info__(:functions)

    assert Visibilities.first() == %Orb.Instruction{
             type: :unknown_effect,
             operation: {:call, [], :first},
             operands: []
           }

    assert Visibilities.second() == %Orb.Instruction{
             type: :unknown_effect,
             operation: {:call, [], :second},
             operands: []
           }

    assert_raise UndefinedFunctionError, &Visibilities.third/0
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

  test "constant strings are mapped into a single address space" do
    defmodule SharedStringConstants do
      use Orb

      defwi foo(), I32.String do
        ~S"foo"
      end

      defwi cdata_start(), I32.String do
        ~S"<![CDATA["
      end
    end

    defmodule SharedStringConsumer do
      use Orb

      Orb.include(SharedStringConstants)
      import SharedStringConstants

      Memory.pages(1)

      defw cdata_start2(), I32.String do
        ~S"<![CDATA["
      end

      defw use_other(), I32.String do
        cdata_start()
      end
    end

    # IO.puts(SharedStringConsumer.to_wat())
    i = Instance.run(SharedStringConsumer)
    # assert Instance.read_memory(i, 0xFF, 20) == ""
    assert Instance.call_reading_string(i, :cdata_start2) == "<![CDATA["
    assert Instance.call_reading_string(i, :use_other) == "<![CDATA["
  end
end
