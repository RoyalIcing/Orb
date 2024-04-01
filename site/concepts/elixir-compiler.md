# Elixir Compiler

Orb lets you use the entire Elixir programming language at WebAssembly compile time.

Elixir has an existing compilation step. This is when its macros are run.

Here how every step is broken down:

1. Elixir is compiled: macros are run.
2. WebAssembly module is compiled: Elixir functions are run.
3. WebAssembly instance is run.

## Running at compile time

## Reduce boilerplate with inlining

- `Orb.snippet`

## Processing blocks with macros
