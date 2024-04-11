defmodule Orb.ModuleDefinition do
  @moduledoc false

  defstruct name: nil,
            types: [],
            table_size: 0,
            imports: [],
            globals: [],
            memory: nil,
            constants: %Orb.Constants{},
            body: [],
            data: []

  @doc false
  def expand_body_func_refs(body) do
    {func_refs, other} = Enum.split_with(body, &match?({:mod_func_ref, _, _}, &1))

    func_refs =
      func_refs
      |> Enum.uniq()
      |> Enum.map(&resolve_func_ref/1)
      |> List.flatten()
      |> Enum.uniq_by(fn func -> {func.source_module, func.name} end)

    body = func_refs ++ other
    body
  end

  def expand_body_func_constants(body) do
    body
    |> Enum.map(fn
      %Orb.Func{} = f ->
        Orb.Func.expand(f)

      other ->
        other
    end)
  end

  def new(options) do
    struct!(__MODULE__, options)
  end

  def get_body_of(mod) do
    mod.__wasm_body__(nil)
    |> expand_body_func_refs()
    |> expand_body_func_constants()
  end

  defp resolve_func_ref({:mod_func_ref, visiblity, {mod, name}}) do
    fetch_func!(get_body_of(mod), visiblity, mod, name)
  end

  defp resolve_func_ref({:mod_func_ref, visiblity, mod}) when is_atom(mod) do
    fetch_func!(get_body_of(mod), visiblity, mod)
  end

  defmodule FetchFuncError do
    defexception [:func_name, :source_module]

    @impl true
    def message(%{func_name: func_name, source_module: source_module}) do
      "funcp #{func_name} not found in #{source_module}"
    end
  end

  def fetch_func!(body, visibility, source_module) when is_list(body) do
    body = List.flatten(body)
    exported? = visibility == :exported

    funcs =
      Enum.flat_map(body, fn
        %Orb.Func{} = func ->
          [
            %{
              func
              | exported_names: if(exported?, do: [func.name], else: []),
                source_module: func.source_module || source_module
            }
          ]

        _ ->
          []
      end)

    funcs
  end

  def fetch_func!(body, visibility, source_module, name) when is_list(body) do
    body = List.flatten(body)
    exported? = visibility == :exported

    # func = Enum.find(body, &match?(%Orb.Func{name: ^name}, &1))
    func =
      Enum.find_value(body, fn
        %Orb.Func{name: ^name} = func ->
          %{
            func
            | exported_names: if(exported?, do: [func.name], else: []),
              source_module: func.source_module || source_module
          }

        _ ->
          false
      end)

    func || raise FetchFuncError, func_name: name, source_module: source_module
  end

  def func_ref!(mod, name) when is_atom(mod) do
    # TODO: convert to struct
    {:mod_func_ref, :exported, {mod, name}}
  end

  def func_ref_all!(mod) when is_atom(mod) do
    {:mod_func_ref, :exported, mod}
  end

  def funcp_ref!(mod, name) when is_atom(mod) do
    {:mod_func_ref, :internal, {mod, name}}
  end

  def funcp_ref_all!(mod) when is_atom(mod) do
    {:mod_func_ref, :internal, mod}
  end

  defimpl Orb.ToWat do
    def to_wat(
          %Orb.ModuleDefinition{
            name: name,
            types: types,
            table_size: table_size,
            imports: imports,
            globals: globals,
            memory: memory,
            constants: constants,
            body: body,
            data: data
          },
          indent
        ) do
      next_indent = "  " <> indent

      # TODO: replace with reading from opts
      name = Process.get(Orb.ModuleDefinition.Name, name)

      [
        [indent, "(module $#{name}", "\n"],
        [for(type <- types, do: [Orb.ToWat.to_wat(type, next_indent), "\n"])],
        [for(import_def <- imports, do: [Orb.ToWat.to_wat(import_def, next_indent), "\n"])],
        case table_size do
          0 -> []
          n -> [next_indent, "(table ", to_string(n), " funcref)\n"]
        end,
        case memory do
          nil ->
            []

          %Orb.Memory{} ->
            Orb.ToWat.to_wat(memory, next_indent)
        end,
        for global = %Orb.Global{} <- globals do
          Orb.ToWat.to_wat(global, next_indent)
        end,
        Orb.ToWat.to_wat(constants, next_indent),
        for data_item = %Orb.Data{} <- data do
          Orb.ToWat.to_wat(data_item, next_indent)
        end,
        for statement <- List.flatten(body) do
          Orb.ToWat.to_wat(statement, next_indent)
        end,
        [indent, ")", "\n"]
      ]
    end
  end

  defimpl Orb.ToWasm do
    import Orb.Leb
    import Orb.ToWasm.Helpers

    @wasm_prefix <<"\0asm", 0x01000000::32>>

    def to_wasm(
          %Orb.ModuleDefinition{
            types: _types,
            table_size: _table_size,
            imports: _imports,
            globals: _globals,
            memory: _memory,
            constants: _constants,
            body: mod_body,
            data: _data
          },
          context
        ) do
      funcs = Enum.with_index(for f = %Orb.Func{} <- mod_body, do: f)

      uniq_func_types =
        for({f, _index} <- funcs, do: func_type_tuple(f))
        |> Enum.uniq()

      func_defs =
        for {f, _index} <- funcs do
          type_to_find = func_type_tuple(f)

          Enum.find_index(uniq_func_types, fn type -> type === type_to_find end)
          |> uleb128()
        end

      export_funcs =
        for {%Orb.Func{exported_names: names}, index} <- funcs, name <- names do
          export_func(name, index)
        end

      func_code = for {f, _index} <- funcs, do: Orb.ToWasm.to_wasm(f, context)

      [
        @wasm_prefix,
        section(:type, vec(for {p, r} <- uniq_func_types, do: func_type(p, r))),
        section(:function, vec(func_defs)),
        section(:export, vec(export_funcs)),
        section(:code, vec(func_code))
      ]
    end

    defp func_type_tuple(%Orb.Func{params: params, result: result}) do
      import Orb.Ops

      params =
        for(param <- params, do: to_primitive_type(param.type))
        |> List.to_tuple()

      result = to_primitive_type(result)

      {params, result}
    end

    defp func_type(params, results) do
      alias Orb.Func.Param

      [
        0x60,
        for types <- [params, results] do
          case types do
            types when is_list(types) ->
              for type <- types, do: Param.to_wasm_type(type)

            types when is_tuple(types) ->
              for type <- Tuple.to_list(types), do: Param.to_wasm_type(type)

            type when is_atom(type) ->
              [Param.to_wasm_type(type)]
          end
          |> vec()
        end
      ]
    end

    defp export_func(name, func_index) do
      [
        sized(name),
        0x00,
        func_index
      ]
    end

    defp section(:custom, bytes), do: section(0x00, bytes)
    defp section(:type, bytes), do: section(0x01, bytes)
    defp section(:import, bytes), do: section(0x02, bytes)
    defp section(:function, bytes), do: section(0x03, bytes)
    defp section(:table, bytes), do: section(0x04, bytes)
    defp section(:memory, bytes), do: section(0x05, bytes)
    defp section(:global, bytes), do: section(0x06, bytes)
    defp section(:export, bytes), do: section(0x07, bytes)
    defp section(:start, bytes), do: section(0x08, bytes)
    defp section(:element, bytes), do: section(0x09, bytes)
    defp section(:code, bytes), do: section(0x0A, bytes)
    defp section(:data, bytes), do: section(0x0B, bytes)
    defp section(:data_count, bytes), do: section(0x0C, bytes)

    defp section(id, bytes) do
      [
        id,
        sized(IO.iodata_to_binary(bytes))
      ]
    end
  end
end
