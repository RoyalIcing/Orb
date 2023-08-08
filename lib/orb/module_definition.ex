defmodule Orb.ModuleDefinition do
  @moduledoc false

  defstruct name: nil,
            types: [],
            table_size: 0,
            imports: [],
            globals: [],
            memory: nil,
            constants: %Orb.Constants{},
            body: []

  def new(options) do
    {body, options} = Keyword.pop(options, :body)

    {func_refs, other} = Enum.split_with(body, &match?({:mod_func_ref, _, _}, &1))

    func_refs =
      func_refs
      |> Enum.uniq()
      |> Enum.map(&resolve_func_ref/1)
      |> List.flatten()
      |> Enum.uniq_by(fn func -> {func.source_module, func.name} end)

    body = func_refs ++ other

    fields = Keyword.put(options, :body, body)
    struct!(__MODULE__, fields)
  end

  defp resolve_func_ref({:mod_func_ref, visiblity, {mod, name}}) do
    fetch_func!(mod.__wasm_module__(), visiblity, mod, name)
  end

  defp resolve_func_ref({:mod_func_ref, visiblity, mod}) when is_atom(mod) do
    fetch_func!(mod.__wasm_module__(), visiblity, mod)
  end

  defmodule FetchFuncError do
    defexception [:func_name, :module_definition]

    @impl true
    def message(%{func_name: func_name, module_definition: module_definition}) do
      "funcp #{func_name} not found in #{module_definition.name} #{inspect(module_definition.body)}"
    end
  end

  def fetch_func!(%__MODULE__{body: body}, visibility, source_module) do
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

  def fetch_func!(%__MODULE__{body: body} = module_definition, visibility, source_module, name) do
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

    func || raise FetchFuncError, func_name: name, module_definition: module_definition
  end

  def func_ref!(mod, name) when is_atom(mod) do
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
    alias Orb.ToWat.Instructions

    def to_wat(
          %Orb.ModuleDefinition{
            name: name,
            types: types,
            table_size: table_size,
            imports: imports,
            globals: globals,
            memory: memory,
            constants: constants,
            body: body
          },
          indent
        ) do
      next_indent = "  " <> indent

      [
        [indent, "(module $#{name}", "\n"],
        [for(type <- types, do: [Orb.ToWat.to_wat(type, next_indent), "\n"])],
        [for(import_def <- imports, do: [Instructions.do_wat(import_def, next_indent), "\n"])],
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
        for statement <- List.flatten(body) do
          Orb.ToWat.to_wat(statement, next_indent)
        end,
        [indent, ")", "\n"]
      ]
    end
  end
end
