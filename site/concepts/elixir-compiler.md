# Elixir Compiler

Orb lets you use the entire Elixir programming language at WebAssembly compile time. This allows you to use existing Elixir libraries or make network requests.

Elixir today has two steps: compile-time and runtime. Compile-time is when its macros are run for example. Orb adds one more step in the middle that straddles the Elixir and WebAssembly worlds.

Here’s each step in Orb:

1. Elixir-compile-time: Elixir macros are run.
2. WebAssembly-compile-time: Elixir functions are run.
3. WebAssembly-runtime: WebAssembly instructions are run.

## 1. Elixir macros at Elixir compile-time

Macros are one of the most powerful features of Elixir. They allow you to transform the abstract syntax tree (AST) of the Elixir language. For example, Ecto’s queries are powered by macros.

### Processing `do` blocks with macros

A common building block in Elixir are `do` blocks. You can consume these “blocks” using Elixir macros, which can unwrap the underlying list of Elixir AST elements. You can then process these elements.

Orb globals are defined using macros consuming `do` blocks. The core piece of Orb `defw` is made using macros and `do` blocks. They end up iterating through each Elixir AST and doing something with it — adding a new global to the list of globals, or adding a new function to the list of WebAssembly functions. They are what most make it feel like you are writing Elixir when using Orb.

## 2. Elixir functions at WebAssembly compile-time

Orb also has its own abstract syntax tree, represented using Elixir structs. You create these structs using helper functions in the Orb DSL. As these are really functions like any other Elixir function, you can compose them like any other Elixir function. Find yourself doing the same 3 things in a row all the time? Wrap it in a function.

### Reduce boilerplate with inlining

`Orb.snippet/1` lets you use the Elixir DSL and return the Orb AST.

Here’s an example of a parser helper that iterates through a list of characters at compile time, mapping each to a WebAssembly instruction to read each character and finally boolean `AND` them all together.

```elixir
defmodule CharParser do
  use Orb

  def parse_chars(chars, offset) when is_list(chars) do
    Orb.snippet do
      chars
      |> Enum.with_index(fn char, index ->
        Memory.load!(I32.U8, offset + index) === char
      end)
      |> Enum.reduce(&I32.band/2)
    end
  end
end
```

The `Memory.load!/2` and `I32.band/2` provide the WebAssembly instructions via Orb’s DSL, while the rest is standard Elixir code. The result is just WebAssembly instructions, effectively inlining the loop at compile time.

## 3. WebAssembly instructions at WebAssembly runtime

Finally we get to the WebAssembly instructions themselves being executed on a WebAssembly runtime like JavaScript’s `WebAssembly.Instance` class or Wasmtime.

The above compilation steps have been done and the WebAssembly instructions have been converted to their runnable format via `Orb.ToWasm` or `Orb.ToWat`. If you need you can implement these protocols yourself.
