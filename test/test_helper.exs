ExUnit.start()

Code.require_file("support/wasmex_case.exs", __DIR__)

defmodule TestHelper do
  defmacro location(plus) do
    caller = __CALLER__
    file = Path.relative_to_cwd(caller.file)
    quote do: "#{unquote(file)}:#{unquote(caller.line) + unquote(plus)}"
  end

  defmacro module_wat(do: block) do
    location = Macro.Env.location(__CALLER__)

    {:module, mod, _, _} =
      Module.create(
        String.to_atom("Elixir.Sample#{location[:line]}"),
        block,
        location
      )

    quote do
      Process.put(Orb.ModuleDefinition.Name, "Sample")
      Orb.to_wat(unquote(mod))
    end
  end

  def wasm_call(source, function), do: do_wasm_call(source, function, [])
  def wasm_call(source, function, arg1), do: do_wasm_call(source, function, [arg1])
  def wasm_call(source, function, arg1, arg2), do: do_wasm_call(source, function, [arg1, arg2])
  def wasm_call(source, function, arg1, arg2, arg3), do: do_wasm_call(source, function, [arg1, arg2, arg3])

  # Stateful instance management for tests that need to maintain state between calls
  def wasm_instance_start(source) do
    source_key = source_cache_key(source)
    case Process.get({:wasm_instance, source_key}) do
      nil ->
        imports = %{}
        {:ok, pid} = Wasmex.start_link(%{bytes: wat_source(source), imports: imports})
        Process.put({:wasm_instance, source_key}, pid)
        pid
      pid -> pid
    end
  end

  def wasm_instance_call(source, function, args \\ []) do
    pid = wasm_instance_start(source)
    wasmex_args = Enum.map(args, &convert_arg_to_wasmex/1)
    {:ok, result} = Wasmex.call_function(pid, to_string(function), wasmex_args)
    
    case result do
      [] -> nil
      [single] -> single
      multiple when is_list(multiple) -> List.to_tuple(multiple)
    end
  end

  defp source_cache_key(source) when is_atom(source), do: {:module, source}
  defp source_cache_key(source) when is_binary(source), do: {:binary, :crypto.hash(:sha256, source)}

  # Safe versions that return {:error, reason} instead of raising
  def safe_wasm_call(source, function), do: do_safe_wasm_call(source, function, [])
  def safe_wasm_call(source, function, arg1), do: do_safe_wasm_call(source, function, [arg1])
  def safe_wasm_call(source, function, arg1, arg2), do: do_safe_wasm_call(source, function, [arg1, arg2])

  defp do_safe_wasm_call(source, function, args) do
    try do
      {:ok, do_wasm_call(source, function, args)}
    rescue
      e -> {:error, e}
    catch
      kind, reason ->
        {:error, {kind, reason}}
    end
  end

  # Helper for reading strings from memory, similar to OrbWasmtime.Instance.call_reading_string
  def wasm_call_reading_string(source, function, args \\ []) do
    imports = %{}
    {:ok, pid} = Wasmex.start_link(%{bytes: wat_source(source), imports: imports})
    
    # Call the function which may return just ptr or {ptr, length}
    {:ok, result} = Wasmex.call_function(pid, to_string(function), args)
    
    # Read the string from memory
    {:ok, memory} = Wasmex.memory(pid)
    {:ok, store} = Wasmex.store(pid)
    
    case result do
      [ptr, length] ->
        # Function returned pointer and length
        binary = Wasmex.Memory.read_binary(store, memory, ptr, length)
        binary |> :binary.split(<<0>>) |> hd() # Remove null terminator if present
      [ptr] ->
        # Function returned only pointer, read null-terminated string
        read_null_terminated_string(store, memory, ptr)
    end
  end

  defp read_null_terminated_string(store, memory, ptr) do
    # Read bytes until we find a null terminator
    read_bytes_until_null(store, memory, ptr, 0, [])
  end

  defp read_bytes_until_null(store, memory, ptr, offset, acc) do
    case Wasmex.Memory.read_binary(store, memory, ptr + offset, 1) do
      <<0>> -> 
        # Found null terminator, return accumulated string
        acc |> Enum.reverse() |> IO.iodata_to_binary()
      <<byte>> -> 
        # Continue reading
        read_bytes_until_null(store, memory, ptr, offset + 1, [byte | acc])
    end
  end

  defp wat_source(source) when is_atom(source), do: Orb.to_wat(source)
  defp wat_source(source) when is_binary(source) do
    # Check if it's binary WASM (starts with magic number) or WAT text
    case source do
      <<0, 97, 115, 109, _::binary>> -> source  # Binary WASM starts with "\0asm"
      _ -> source  # Assume it's WAT text
    end
  end

  defp do_wasm_call(source, function, args) when is_atom(source) do
    do_wasm_call(Orb.to_wat(source), function, args)
  end

  defp do_wasm_call(source, function, args) do
    source_bytes = wat_source(source)
    
    # Convert arguments to Wasmex format
    wasmex_args = Enum.map(args, &convert_arg_to_wasmex/1)
    
    # Check if this is a stateful test by looking for global variables in the source
    # For binary WASM, we'll default to stateless for now
    is_stateful = case source_bytes do
      <<0, 97, 115, 109, _::binary>> -> false  # Binary WASM - assume stateless
      wat_text -> String.contains?(wat_text, "(global ")
    end
    
    if is_stateful do
      # Use stateful instance for modules with globals
      wasm_instance_call(source, function, wasmex_args)
    else
      # Use ephemeral instance for stateless modules
      imports = %{}
      {:ok, pid} = Wasmex.start_link(%{bytes: source_bytes, imports: imports})
      
      {:ok, result} = Wasmex.call_function(pid, to_string(function), wasmex_args)
      
      case result do
        [] -> nil
        [single] -> single
        multiple when is_list(multiple) -> List.to_tuple(multiple)
      end
    end
  end

  # Convert OrbWasmtime-style arguments to Wasmex format
  defp convert_arg_to_wasmex({:i64, value}), do: value
  defp convert_arg_to_wasmex({:i32, value}), do: value
  defp convert_arg_to_wasmex({:f32, value}), do: value
  defp convert_arg_to_wasmex({:f64, value}), do: value
  defp convert_arg_to_wasmex(value), do: value
end
