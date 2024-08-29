defmodule Orb.Compiler do
  @moduledoc false

  def run(mod, globals) do
    global_types =
      globals
      |> List.flatten()
      |> Map.new(fn global -> {global.name, global.type} end)
      |> Map.merge(%{__MODULE__: mod})

    Process.put({Orb, :global_types}, global_types)
    Orb.Constants.__begin()

    # Each global is expanded, possibly looking up with the current compiler context begun above.
    global_defs =
      globals |> Enum.reverse() |> List.flatten() |> Enum.map(&Orb.Global.expand!/1)

    body = Orb.ModuleDefinition.get_body_of(mod)

    data_defs = mod.__wasm_data_defs__(nil)

    Process.delete({Orb, :global_types})

    # We’re done. Get all the constant strings that were actually used.
    constants = Orb.Constants.__read()

    %{
      body: body,
      constants: constants,
      global_defs: global_defs,
      data_defs: data_defs
    }
  after
    Orb.Constants.__cleanup()
  end
end
