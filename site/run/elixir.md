# Running WebAssembly in Elixir

First install Orb and Wasmex:

```elixir
Mix.install([
  {:jason, "~> 1.0"},
  :orb,
  {:wasmex, "~> 0.8.3"}
])
```

Define your WebAssembly module in Elixir using Orb:

```elixir
defmodule CalculateMean do
  use Orb

  global do
    @tally 0
    @count 0
  end

  defw insert(n: I32) do
    @tally = @tally + n
    @count = @count + 1
  end

  defw calculate_mean(), I32 do
    @tally / @count
  end
end
```

Now run your WebAssembly module using Wasmex:

```elixir
{:ok, pid} = Wasmex.start_link(%{bytes: Orb.to_wat(CalculateMean)})
Wasmex.call_function(pid, :insert, [3])
Wasmex.call_function(pid, :insert, [4])
Wasmex.call_function(pid, :insert, [5])
Wasmex.call_function(pid, :insert, [6])
Wasmex.call_function(pid, :insert, [7])
{:ok, [5]} = Wasmex.call_function(pid, :calculate_mean, [])
```
