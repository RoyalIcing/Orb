defmodule Orb.Table do
  defmodule Type do
    @callback type_name() :: atom()
    @callback table_func_keys() :: list(atom())
  end

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
      lookup_table =
        accumulated_value
        |> Enum.reverse()
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
          {table_module, table_key} = key

          raise "Could not find elem key #{inspect(table_key)} from table module #{table_module} in table allocations #{inspect(lookup_table)}"

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

  def do_elem(caller_mod, f, mod, key) do
    # if Process.put(Orb.DSL, false) do
    if function_exported?(caller_mod, :__wasm_table_allocations__, 0) do
      Orb.Func.__add_table_elem(
        f,
        Allocations.fetch_index!(caller_mod.__wasm_table_allocations__(), {mod, key})
      )
    else
      f
    end
  end

  defmacro elem!(f, mod, key) do
    caller_mod = __CALLER__.module

    quote do
      unquote(__MODULE__).do_elem(unquote(caller_mod), unquote(f), unquote(mod), unquote(key))

      # Orb.Func.__add_table_elem(unquote(f), Allocations.fetch_index!(unquote(caller_mod).__wasm_table_allocations__(), {unquote(mod), unquote(key)}))
    end
  end

  defmacro fetch!(key) do
    quote do
      Allocations.fetch!(__wasm_table_allocations__(), unquote(key))
    end
  end

  defmacro lookup!(key) do
    caller_mod = __CALLER__.module

    quote do
      Allocations.fetch_index!(unquote(caller_mod).__wasm_table_allocations__(), unquote(key))
    end
  end

  defmacro lookup!(table_mod, key) do
    caller_mod = __CALLER__.module

    quote do
      Allocations.fetch_index!(
        unquote(caller_mod).__wasm_table_allocations__(),
        {unquote(table_mod), unquote(key)}
      )
    end
  end

  # def elem(f = %Orb.Func{}, elem_ref) when is_function(elem_ref) do
  #   update_in(f.table_elem_refs, fn refs -> [elem_ref | refs] end)
  # end

  defmodule CallIndirect do
    @moduledoc false

    defstruct pop_type: nil,
              push_type: nil,
              type_signature: nil,
              table_index: 0,
              arguments: []

    defimpl Orb.ToWat do
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
          ") (i32.const ",
          to_string(table_index),
          ?),
          for(arg <- arguments, do: [" ", Orb.ToWat.to_wat(arg, "")]),
          ?)
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

  def call_indirect(func_type, type_signature, table_index) do
    do_call_indirect(func_type, type_signature, table_index, [])
  end

  def call_indirect(func_type, type_signature, table_index, arg1) do
    do_call_indirect(func_type, type_signature, table_index, [arg1])
  end

  def call_indirect(func_type, type_signature, table_index, arg1, arg2) do
    do_call_indirect(func_type, type_signature, table_index, [arg1, arg2])
  end

  def call_indirect(func_type, type_signature, table_index, arg1, arg2, arg3) do
    do_call_indirect(func_type, type_signature, table_index, [arg1, arg2, arg3])
  end

  def call_indirect(func_type, type_signature, table_index, arg1, arg2, arg3, arg4) do
    do_call_indirect(func_type, type_signature, table_index, [arg1, arg2, arg3, arg4])
  end

  defp do_call_indirect(func_type = %Orb.Func.Type{}, type_signature, table_index, arguments) do
    %CallIndirect{
      pop_type: if(func_type.params, do: for(param <- func_type.params, do: param.type)),
      push_type: func_type.result,
      type_signature: type_signature,
      table_index: table_index,
      arguments: arguments
    }
  end
end
