# Elixir Compiler

Orb lets you use the entire Elixir programming language at WebAssembly compile time. This allows you to use existing Elixir libraries or make network requests.

Elixir today has two steps: compile-time and runtime. Compile-time is when its macros are run for example. Orb adds one more step in the middle that straddles the Elixir and WebAssembly worlds.

Here how each step is broken down:

1. Elixir-compile-time: Elixir macros are run.
2. WebAssembly-compile-time: Elixir functions are run.
3. WebAssembly-runtime: WebAssembly instance is run.

## 1. Elixir macros at Elixir compile-time

Macros are one of the most powerful features of Elixir. They allow you to transform the abstract syntax tree (AST) of the Elixir language. For example, Ecto’s queries are powered by macros.

### Processing `do` blocks with macros

A common building block in Elixir are `do` blocks. You can consume these “blocks” using Elixir macros, which can unwrap the underlying list of Elixir AST elements. You can then process these elements.

Orb globals are defined using macros consuming `do` blocks. The core piece of Orb `defw` is made using macros and `do` blocks. They end up iterating through each Elixir AST and doing something with it — adding a new global to the list of globals, or adding a new function to the list of WebAssembly functions. They are what most make it feel like you are writing Elixir when using Orb.

## 2. Elixir functions at WebAssembly compile-time

Orb also has its own abstract syntax tree, represented using Elixir structs. You create these structs using helper functions in the Orb DSL. As these are really functions like any other Elixir function, you can compose them like any other Elixir function. Find yourself doing the same 3 things in a row all the time? Wrap it in a function.

### Reduce boilerplate with inlining

`Orb.snippet/1` lets you use the Elixir DSL and return the Orb AST.

## 3. WebAssembly instructions at WebAssembly runtime

Finally we get to the WebAssembly instructions themselves being executed on a WebAssembly runtime like Wasmtime or JavaScript’s `WebAssembly.Instance` class.