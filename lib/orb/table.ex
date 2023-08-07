defmodule Orb.Table do
  defmacro allocate(entries) when is_list(entries) do
    quote do
      @wasm_table_allocations unquote(entries)
    end
  end

  # def elem(f = %Orb.Func{}) when is_atom(f.name) do
  #   update_in(f.table_elem_refs, fn refs -> [f.name | refs] end)
  # end

  defmacro elem(f, identifier) do
    quote do
      Orb.Func.__add_table_elem(unquote(f), @wasm_table_allocations, unquote(identifier))
    end
  end

  # def elem(f = %Orb.Func{}, elem_ref) when is_function(elem_ref) do
  #   update_in(f.table_elem_refs, fn refs -> [elem_ref | refs] end)
  # end

  defmodule CallIndirect do
    defstruct type_signature: nil,
              table_index: 0,
              arguments: []

    defimpl Orb.ToWat do
      alias Orb.ToWat.Instructions

      def to_wat(
            %Orb.Table.CallIndirect{
              type_signature: type_signature,
              table_index: table_index,
              arguments: arguments
            },
            indent
          ) do
        [
          indent,
          "(call_indirect (type $",
          to_string(type_signature),
          ") ",
          Instructions.do_wat(table_index),
          for(arg <- arguments, do: [" ", Instructions.do_wat(arg)]),
          ")"
        ]
      end
    end
  end

  def call(type_signature, table_index) do
    %CallIndirect{type_signature: type_signature, table_index: table_index}
  end

  def call(type_signature, table_index, arg1) do
    %CallIndirect{type_signature: type_signature, table_index: table_index, arguments: [arg1]}
  end

  def call(type_signature, table_index, arg1, arg2) do
    %CallIndirect{
      type_signature: type_signature,
      table_index: table_index,
      arguments: [arg1, arg2]
    }
  end

  def call(type_signature, table_index, arg1, arg2, arg3) do
    %CallIndirect{
      type_signature: type_signature,
      table_index: table_index,
      arguments: [arg1, arg2, arg3]
    }
  end

  def call(type_signature, table_index, arg1, arg2, arg3, arg4) do
    %CallIndirect{
      type_signature: type_signature,
      table_index: table_index,
      arguments: [arg1, arg2, arg3, arg4]
    }
  end
end
