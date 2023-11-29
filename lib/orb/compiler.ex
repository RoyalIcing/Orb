defmodule Orb.Compiler do
  @moduledoc false

  def get_body_of(mod) do
    mod.__wasm_body__(nil)
    |> Orb.ModuleDefinition.expand_body_func_refs()
    |> Orb.ModuleDefinition.expand_body_func_constants()
  end

  def run(mod, globals) do
    global_types =
      globals
      |> List.flatten()
      |> Map.new(fn global -> {global.name, global.type} end)
      |> Map.merge(%{__MODULE__: mod})

    Process.put({Orb, :global_types}, global_types)
    Orb.Constants.__begin()

    # Each global is expanded, possibly looking up with the current compiler context begun above.
    global_definitions =
      globals |> Enum.reverse() |> List.flatten() |> Enum.map(&Orb.Global.expand!/1)

    body = get_body_of(mod)

    Process.delete({Orb, :global_types})

    # We’re done. Get all the constant strings that were actually used.
    constants = Orb.Constants.__done()

    %{body: body, constants: constants, global_definitions: global_definitions}
  end
end
