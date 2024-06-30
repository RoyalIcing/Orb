defmodule DefwTest do
  use ExUnit.Case, async: true
  alias OrbWasmtime.Instance

  require TestHelper

  test "globals work" do
    assert (TestHelper.module_wat do
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
      i32(1)
      |> Orb.Stack.drop()
    end

    defwp second() do
      i32(3)
      |> Orb.Stack.drop()
    end

    def __shush_warning, do: second()
  end

  test "function visiblity" do
    assert Visibilities.to_wat() =~ """
             (func $first (export "first")
               (i32.const 1)
               drop
             )
             (func $second
               (i32.const 3)
               drop
             )
           """

    assert {:first, 0} in Visibilities.__info__(:functions)
    refute {:second, 0} in Visibilities.__info__(:functions)

    assert Visibilities.first() == %Orb.Instruction{
             operation: {:call, [], :first},
             operands: []
           }

    assert_raise UndefinedFunctionError, &Visibilities.second/0
  end

  test "multiple args errs" do
    assert_raise CompileError,
                 ~r[#{TestHelper.location(+5)}: Cannot define function with multiple arguments, use keyword list instead.],
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

      defw foo(), Orb.Constants.NulTerminatedString do
        ~S"foo"
      end

      defw cdata_start(), Orb.Constants.NulTerminatedString do
        ~S"<![CDATA["
      end
    end

    defmodule SharedStringConsumer do
      use Orb

      Orb.include(SharedStringConstants)
      import SharedStringConstants

      Memory.pages(1)

      defw cdata_start2(), Orb.Constants.NulTerminatedString do
        ~S"<![CDATA["
      end

      defw use_other(), Orb.Constants.NulTerminatedString do
        cdata_start()
      end
    end

    # IO.puts(SharedStringConsumer.to_wat())
    i = Instance.run(SharedStringConsumer)
    # assert Instance.read_memory(i, 0xFF, 20) == ""
    assert Instance.call_reading_string(i, :cdata_start2) == "<![CDATA["
    assert Instance.call_reading_string(i, :use_other) == "<![CDATA["
  end

  test "can unquote name" do
    defmodule MacroWithDefw do
      defmacro defw_wrapper(name) do
        quote do
          Orb.DSL.Defw.defw unquote(name)() do
          end
        end
      end
    end

    defmodule Unquoted do
      use Orb

      defw unquote(:first)() do
      end

      require MacroWithDefw
      MacroWithDefw.defw_wrapper(:second)
    end

    assert ~S"""
           (module $Unquoted
             (func $first (export "first")
             )
             (func $second (export "second")
             )
           )
           """ = Orb.to_wat(Unquoted)
  end
end
