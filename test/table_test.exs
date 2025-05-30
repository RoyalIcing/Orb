defmodule TableTest do
  use ExUnit.Case, async: true
  require TestHelper

  test "simple table with call_indirect" do
    defmodule SimpleTable do
      use Orb

      defmodule Answer do
        @behaviour Orb.CustomType
        @behaviour Orb.Table.Type

        @impl Orb.CustomType
        def wasm_type, do: %Orb.Func.Type{result: I32}

        @impl Orb.CustomType
        def type_name, do: :answer

        @impl Orb.Table.Type
        def table_func_keys, do: [:good]

        def call(elem_index) do
          Table.call_indirect(wasm_type(), type_name(), elem_index)
        end
      end

      types([Answer])
      Table.allocate(Answer)

      @table {Answer, :good}
      defw good_answer(), I32 do
        42
      end

      defw test(), I32 do
        Answer.call(Table.lookup!(Answer, :good))
      end
    end

    wat = Orb.to_wat(SimpleTable)

    # Test that WAT contains expected structure
    assert wat =~ "(type $answer (func (result i32)))"
    assert wat =~ "(table"
    assert wat =~ "call_indirect"

    # Test that WAT works
    assert TestHelper.wasm_call(wat, :test) === 42

    # Now test WASM binary - just ensure it generates without crashing
    wasm = Orb.to_wasm(SimpleTable)

    # Basic structure checks
    assert <<"\0asm", 0x01000000::32, _rest::binary>> = wasm
    assert byte_size(wasm) > 20
  end

  test "basic module without tables should work" do
    defmodule BasicModule do
      use Orb

      defw simple_func(), I32 do
        42
      end
    end

    wat = Orb.to_wat(BasicModule)
    wasm = Orb.to_wasm(BasicModule)

    # Both should work
    assert TestHelper.wasm_call(wat, :simple_func) === 42
    assert TestHelper.wasm_call(wasm, :simple_func) === 42
  end
end
