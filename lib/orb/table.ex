defmodule Orb.Table do
  defmacro allocate(entries) do
    quote do
      @wasm_table_allocations unquote(__MODULE__).__do_allocate(unquote(entries))
    end
  end

  def __do_allocate(mod) when is_atom(mod) do
    type_name = mod.type_name()
    for key <- mod.table_func_keys() do
      {{mod, key}, type_name}
    end
    |> __do_allocate()

    # __do_allocate(mod.table_entries())
  end

  def __do_allocate(list) when is_list(list) do
    list
  end

  defmodule Allocations do
    @moduledoc false

    defstruct lookup_table: []

    def from_attribute(accumulated_value) do
      lookup_table = accumulated_value
      |> List.flatten()
      |> Enum.with_index(fn {key, type}, index ->
        {key, {index, type}}
      end)
      |> Map.new()

      %__MODULE__{lookup_table: lookup_table}
    end

    def fetch!(%__MODULE__{lookup_table: lookup_table}, key) do
      case Map.fetch(lookup_table, key) do
        :error ->
          raise "Could not find elem key #{inspect(key)} in table allocations #{inspect(lookup_table)}"

        {:ok, result} ->
          result
      end
    end

    def fetch_index!(%__MODULE__{} = self, key) do
      {elem_index, _type} = fetch!(self, key)
      elem_index
    end
  end

  # def elem(f = %Orb.Func{}) when is_atom(f.name) do
  #   update_in(f.table_elem_refs, fn refs -> [f.name | refs] end)
  # end

  defmacro elem!(f, key) do
    quote do
      Orb.Func.__add_table_elem(unquote(f), Allocations.fetch_index!(__wasm_table_allocations__(), unquote(key)))
    end
  end

  defmacro elem!(f, mod, key) do
    quote do
      Orb.Func.__add_table_elem(unquote(f), Allocations.fetch_index!(__wasm_table_allocations__(), {unquote(mod), unquote(key)}))
    end
  end

  defmacro fetch!(key) do
    quote do
      Allocations.fetch!(__wasm_table_allocations__(), unquote(key))
    end
  end

  defmacro lookup!(key) do
    quote do
      Allocations.fetch_index!(__wasm_table_allocations__(), unquote(key))
    end
  end

  defmacro lookup!(mod, key) do
    quote do
      Allocations.fetch_index!(__wasm_table_allocations__(), {unquote(mod), unquote(key)})
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

  def call({table_index, type_signature}) do
    %CallIndirect{type_signature: type_signature, table_index: table_index}
  end

  def call({table_index, type_signature}, arg1) do
    %CallIndirect{type_signature: type_signature, table_index: table_index, arguments: [arg1]}
  end

  def call({table_index, type_signature}, arg1, arg2) do
    %CallIndirect{
      type_signature: type_signature,
      table_index: table_index,
      arguments: [arg1, arg2]
    }
  end

  def call({table_index, type_signature}, arg1, arg2, arg3) do
    %CallIndirect{
      type_signature: type_signature,
      table_index: table_index,
      arguments: [arg1, arg2, arg3]
    }
  end

  def call({table_index, type_signature}, arg1, arg2, arg3, arg4) do
    %CallIndirect{
      type_signature: type_signature,
      table_index: table_index,
      arguments: [arg1, arg2, arg3, arg4]
    }
  end

  def call_indirect(type_signature, table_index) do
    %CallIndirect{type_signature: type_signature, table_index: table_index}
  end

  def call_indirect(type_signature, table_index, arg1) do
    %CallIndirect{type_signature: type_signature, table_index: table_index, arguments: [arg1]}
  end

  def call_indirect(type_signature, table_index, arg1, arg2) do
    %CallIndirect{
      type_signature: type_signature,
      table_index: table_index,
      arguments: [arg1, arg2]
    }
  end

  def call_indirect(type_signature, table_index, arg1, arg2, arg3) do
    %CallIndirect{
      type_signature: type_signature,
      table_index: table_index,
      arguments: [arg1, arg2, arg3]
    }
  end

  def call_indirect(type_signature, table_index, arg1, arg2, arg3, arg4) do
    %CallIndirect{
      type_signature: type_signature,
      table_index: table_index,
      arguments: [arg1, arg2, arg3, arg4]
    }
  end
end
