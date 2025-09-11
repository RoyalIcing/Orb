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

  # TODO: move this to Orb.Compiler
  def get_body_of(mod) do
    mod.__wasm_body__(nil)
    |> expand_body_func_refs()
    |> expand_body_func_constants()
  end

  defp resolve_func_ref({:mod_func_ref, visibility, {mod, name}}) do
    fetch_func!(get_body_of(mod), visibility, mod, name)
  end

  defp resolve_func_ref({:mod_func_ref, visibility, mod}) when is_atom(mod) do
    # FIXME: don’t repeatedly call get_body_of, instead call it once per module.
    fetch_func!(get_body_of(mod), visibility, mod)
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

    Enum.flat_map(body, fn
      %Orb.Func{} = func ->
        count = Orb.Compiler.count_func_calls(func.name)

        if count > 0 do
          [
            %{
              func
              | exported_names: if(exported?, do: [func.name], else: []),
                source_module: func.source_module || source_module
            }
          ]
        else
          []
        end

      _ ->
        []
    end)
  end

  def fetch_func!(body, visibility, source_module, name) when is_list(body) do
    body = List.flatten(body)
    exported? = visibility == :exported

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

  # TODO: unused
  def func_ref!(mod, name) when is_atom(mod) do
    # TODO: convert to struct
    {:mod_func_ref, :exported, {mod, name}}
  end

  # TODO: unused
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
            types: types,
            table_size: table_size,
            imports: imports,
            globals: globals,
            memory: memory,
            constants: constants,
            body: mod_body,
            data: data
          },
          context
        ) do
      types_indexed = types |> Enum.with_index(&{&1.name, &2})
      globals_indexed = globals |> Enum.with_index()
      imports_indexed = imports |> Enum.with_index()

      funcs = Enum.with_index(for f = %Orb.Func{} <- mod_body, do: f)

      # Extract imported functions for function index space
      imported_funcs =
        for {%Orb.Import{type: %Orb.Func.Type{name: name}}, index} <- imports_indexed,
            not is_nil(name) do
          {name, index}
        end

      # Local functions start after imported functions
      local_func_names =
        for {f, local_index} <- funcs do
          {f.name, local_index + length(imported_funcs)}
        end

      # Combine imported and local function indexes
      all_func_indexes = Map.new(imported_funcs ++ local_func_names)

      # Extract function types from custom types
      custom_func_types =
        for {custom_type, _} <- types_indexed do
          if is_atom(custom_type) and function_exported?(custom_type, :wasm_type, 0) do
            # Get the actual function type from the custom type
            func_type = custom_type.wasm_type()

            case func_type do
              %Orb.Func.Type{params: params, result: result} ->
                # Convert params to tuple format
                params_tuple =
                  if params do
                    case params do
                      params when is_list(params) -> List.to_tuple(params)
                      params when is_tuple(params) -> params
                      param -> {param}
                    end
                  else
                    {}
                  end

                {params_tuple, result}

              _ ->
                # Fallback for unexpected format
                {{}, nil}
            end
          else
            # Fallback for non-custom types (should not happen in this context)
            {{}, nil}
          end
        end

      # Combine custom types and actual function types
      uniq_func_types =
        (custom_func_types ++
           for({f, _index} <- funcs, do: func_type_tuple(f)))
        |> Enum.uniq()

      context =
        context
        |> Orb.ToWasm.Context.set_custom_type_index_lookup(Map.new(types_indexed))
        |> Orb.ToWasm.Context.set_global_name_index_lookup(
          Map.new(globals_indexed, fn {g, index} -> {g.name, index} end)
        )
        |> Orb.ToWasm.Context.set_func_name_index_lookup(all_func_indexes)

      global_defs =
        for global <- globals do
          Orb.ToWasm.to_wasm(global, context)
        end

      func_defs =
        for {f, _index} <- funcs do
          type_to_find = func_type_tuple(f)

          Enum.find_index(uniq_func_types, fn type -> type === type_to_find end)
          |> leb128_u()
        end

      export_globals =
        for {%Orb.Global{exported?: true, name: name}, index} <- globals_indexed do
          encode_export_global(to_string(name), index)
        end

      export_funcs =
        for {%Orb.Func{exported_names: names}, index} <- funcs, name <- names do
          encode_export_func(name, index)
        end

      export_memories =
        case memory do
          nil ->
            []

          %{import_or_export: {:export, exported_name}} ->
            [
              [
                sized(exported_name),
                0x02,
                leb128_u(0)
              ]
            ]

          %{import_or_export: {:import, _, _}} ->
            []
        end

      func_code = for {f, _index} <- funcs, do: Orb.ToWasm.to_wasm(f, context)

      data_defs =
        for data_item = %Orb.Data{} <- data do
          Orb.ToWasm.to_wasm(data_item, context)
        end

      constants_defs = Orb.ToWasm.to_wasm(constants, context)

      import_defs =
        for {import_item = %Orb.Import{}, _index} <- imports_indexed do
          Orb.ToWasm.to_wasm(import_item, context)
        end

      table_def =
        if table_size && table_size > 0 do
          [
            # funcref type
            [0x70],
            # limits: min only
            [0x00, leb128_u(table_size)]
          ]
        else
          nil
        end

      # Generate element segments for table functions
      element_defs =
        for {%Orb.Func{table_elem_indices: indices}, func_index} <- funcs,
            elem_index <- indices do
          [
            # table index (always 0 for single table)
            [0x00],
            # i32.const offset
            [0x41, leb128_u(elem_index)],
            # end
            [0x0B],
            # function index
            vec([leb128_u(func_index)])
          ]
        end

      [
        @wasm_prefix,
        section(:type, vec(for {p, r} <- uniq_func_types, do: encode_func_type(p, r))),
        if import_defs != [] do
          section(:import, vec(import_defs))
        else
          []
        end,
        section(:function, vec(func_defs)),
        if table_def do
          section(:table, vec([table_def]))
        else
          []
        end,
        if memory do
          section(:memory, vec([Orb.ToWasm.to_wasm(memory, context)]))
        else
          []
        end,
        if global_defs != [] do
          section(:global, vec(global_defs))
        else
          []
        end,
        case export_memories ++ export_globals ++ export_funcs do
          [] ->
            []

          export_defs ->
            section(:export, vec(export_defs))
        end,
        if element_defs != [] do
          section(:element, vec(element_defs))
        else
          []
        end,
        # section(:data_count, vec([])),
        section(:code, vec(func_code)),
        case constants_defs ++ data_defs do
          [] -> []
          constants_wasm -> section(:data, vec(constants_wasm))
        end
      ]
    end

    defp func_type_tuple(%Orb.Func{params: params, result: result}) do
      import Orb.Ops

      params =
        for(param <- params, do: to_primitive_type(param.type))
        |> List.to_tuple()

      result = if result, do: to_primitive_type(result)

      {params, result}
    end

    defp encode_func_type(params, results) do
      alias Orb.Func.Param

      [
        0x60,
        for types <- [params, results] do
          case types do
            types when is_list(types) ->
              for type <- types, do: Param.to_wasm_type(type)

            types when is_tuple(types) ->
              for type <- Tuple.to_list(types), do: Param.to_wasm_type(type)

            nil ->
              []

            type when is_atom(type) ->
              [to_wasm_type(type)]
          end
          |> vec()
        end
      ]
    end

    defp encode_export_func(name, func_index) do
      [
        sized(name),
        0x00,
        leb128_u(func_index)
      ]
    end

    defp encode_export_global(name, global_index) do
      [
        sized(name),
        0x03,
        leb128_u(global_index)
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
    defp section(:data_count, bytes), do: section(0x0C, bytes)
    defp section(:code, bytes), do: section(0x0A, bytes)
    defp section(:data, bytes), do: section(0x0B, bytes)

    defp section(id, bytes) do
      [
        id,
        sized(IO.iodata_to_binary(bytes))
      ]
    end
  end
end
