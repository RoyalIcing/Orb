defmodule Orb.Compiler do
  @moduledoc false

  def begin() do
    Orb.Constants.__begin()
  end

  def done() do
    %{constants: Orb.Constants.__done()}
  end

  def get_body_of(mod) do
    mod.__wasm_body__(nil)
    |> Orb.ModuleDefinition.expand_body_func_refs()
  end

  def get_module_definition_of(mod) do
    body = get_body_of(mod)
    body
  end
end
