defmodule Orb.Compiler do
  @moduledoc false

  def begin(opts) do
    global_types = Keyword.fetch!(opts, :global_types)
    Process.put({Orb, :global_types}, global_types)
    Orb.Constants.__begin()
  end

  def done() do
    Process.delete({Orb, :global_types})

    %{constants: Orb.Constants.__done()}
  end

  def get_body_of(mod) do
    mod.__wasm_body__(nil)
    |> Orb.ModuleDefinition.expand_body_func_refs()
    |> Orb.ModuleDefinition.expand_body_func_constants()
  end

  def get_module_definition_of(mod) do
    body = get_body_of(mod)
    body
  end
end
