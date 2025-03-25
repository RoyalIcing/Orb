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

    assert Visibilities.first() == %Orb.Instruction.Call{
             push_type: nil,
             args: [],
             func_identifier: :first
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

  test "Str argument is flattened into two params" do
    defmodule AcceptStr do
      use Orb

      defwp str_length(a: Str), I32 do
        a[:size]
      end

      defwp middleman(a: Str), I32 do
        str_length(a)
      end

      defwp sets_var(a: Str), I32, b: Str do
        b = a
        b = "Z"
        b = abcde()
        b[:size]
      end

      defwp abcde(), Str do
        "abcde"
      end

      defw example(), {I32, I32} do
        {middleman("abc"), sets_var("abc")}
      end
    end

    assert ~S"""
           (module $AcceptStr
             (memory (export "memory") 1)
             (; constants 12 bytes ;)
             (data (i32.const 255) "abc")
             (data (i32.const 259) "Z")
             (data (i32.const 261) "abcde")
             (func $str_length (param $a.ptr i32) (param $a.size i32) (result i32)
               (local.get $a.size)
             )
             (func $middleman (param $a.ptr i32) (param $a.size i32) (result i32)
               (call $str_length (local.get $a.ptr) (local.get $a.size))
             )
             (func $sets_var (param $a.ptr i32) (param $a.size i32) (result i32)
               (local $b.ptr i32)
               (local $b.size i32)
               (local.get $a.ptr)
               (local.set $b.ptr)
               (local.get $a.size)
               (local.set $b.size)
               (i32.const 259) (i32.const 1)
               (local.set $b.size)
               (local.set $b.ptr)
               (call $abcde)
               (local.set $b.size)
               (local.set $b.ptr)
               (local.get $b.size)
             )
             (func $abcde (result i32 i32)
               (i32.const 261) (i32.const 5)
             )
             (func $example (export "example") (result i32 i32)
               (call $middleman (i32.const 255) (i32.const 3))
               (call $sets_var (i32.const 255) (i32.const 3))
             )
           )
           """ = Orb.to_wat(AcceptStr)

    i = Instance.run(AcceptStr)
    assert Instance.call(i, :example) == {3, 5}
  end

  test "constant strings are mapped into a single address space" do
    defmodule SharedStringConstants do
      use Orb

      defw foo(), Str do
        ~S"foo"
      end

      defw cdata_start(), Str do
        ~S"<![CDATA["
      end
    end

    defmodule SharedStringConsumer do
      use Orb

      Orb.include(SharedStringConstants)
      import SharedStringConstants

      Memory.pages(1)

      defw cdata_start2(), Str do
        ~S"<![CDATA["
      end

      defw use_other(), Str do
        cdata_start()
      end
    end

    wat = Orb.to_wat(SharedStringConsumer)
    wasm = Orb.to_wasm(SharedStringConsumer)

    if false do
      path_wat = Path.join(__DIR__, "shared_string.wat")
      path_wasm = Path.join(__DIR__, "shared_string.wasm")
      File.write!(path_wat, wat)
      File.write!(path_wasm, wasm)
      System.cmd("wasm-validate", [path_wasm])
    end

    # TODO: switch to Wasmex so we can run wasm binaries properly
    for source <- [wat] do
      # IO.puts(SharedStringConsumer.to_wat())
      i = Instance.run(source)
      # assert Instance.read_memory(i, 0xFF, 20) == ""
      assert Instance.call_reading_string(i, :cdata_start2) == "<![CDATA["
      assert Instance.call_reading_string(i, :use_other) == "<![CDATA["
    end
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
