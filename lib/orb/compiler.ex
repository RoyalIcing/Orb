defmodule Orb.Compiler do
  @moduledoc false

  def run(mod, globals) do
    tid = :ets.new(__MODULE__, [:set, :private])
    Process.put(__MODULE__, tid)

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

    Process.delete(__MODULE__) |> :ets.delete()
  end

  def will_call_func(func_name) do
    tid = Process.get(__MODULE__) || raise "Must be compiling"
    key = {:func, func_name}
    :ets.update_counter(tid, key, {2, 1}, {key, 1})
  end

  def count_func_calls(func_name) do
    tid = Process.get(__MODULE__) || raise "Must be compiling"
    key = {:func, func_name}
    case :ets.lookup(tid, key) do
      [{^key, count}] when is_integer(count) -> count
      _ -> 0
    end
  end
end
