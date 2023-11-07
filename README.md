![Orb logo](orb-logo-orange.svg)

# Orb: Write WebAssembly with Elixir

Orb lets you write WebAssembly with the power of Elixir as a compiler:

- Use Elixir’s module system to break problems down and compose them together
- `|>` Function piping
- Powerful macros
- Inline code and for-comprehensions
- Run dynamic Elixir code at compile time e.g. feature flags, talk to outside services
- Compile on-the-fly e.g. custom WebAssembly module per user
- Publish reusable code with the Hex package manager

## Installation

The package can be installed via Hex by adding `orb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:orb, "~> 0.0.24"}
  ]
end
```

## Example

```elixir
defmodule CalculateMean do
  use Orb

  I32.global(
    count: 0,
    tally: 0
  )

  defw insert(element: I32) do
    @count = @count + 1
    @tally = @tally + element
  end

  defw calculate_mean(), I32 do
    @tally / @count
  end
end

Orb.to_wat(CalculateMean)
# """
# (module $CalculateMean
#   (global $count (mut i32) (i32.const 0))
#   (global $tally (mut i32) (i32.const 0))
#   (func $insert (export "insert") (param $element i32)
#     (i32.add (global.get $count) (i32.const 1))
#     (global.set $count)
#     (i32.add (global.get $tally) (local.get $element))
#     (global.set $tally)
#   )
#   (func $calculate_mean (export "calculate_mean") (result i32)
#     (i32.div_s (global.get $tally) (global.get $count))
#   )
# )
# """
```

Run with [OrbWasmtime](https://github.com/RoyalIcing/OrbWasmtime):

```elixir
alias OrbWasmtime.Instance

# Run above example
inst = Instance.run(CalculateMean)
Instance.call(inst, :insert, 4)
Instance.call(inst, :insert, 5)
Instance.call(inst, :insert, 6)
assert Instance.call(inst, :calculate_mean) == 5
```

Note there is [another excellent Elixir Wasmtime wrapper out there called Wasmex](https://github.com/tessi/wasmex), you may want to check that out too.

## Use cases

- Write a HTML component and run it in:
    - Phoenix LiveView & dead views
    - In the browser using `<wasm-html>` custom element
- LiveView and its server rendering is a fantastic default, but the latency can be noticeable for certain UI interactions. With Orb you could use Elixir to write a WebAssembly module that then runs in the user’s browser.
- State machines
- Parsers
- Formatters & string builders
- Interactive color picker controls
- Animation that runs fast in the browser, and works on the server
- Code generators

## Why WebAssembly?

- It runs on all of today’s major platforms: browser, server, edge, mobile, laptop, tablet, desktop.
- Universal/isomorphic components (ones that run on the server and browser) are possible in React and Next.js, but they have many different flavours and can get pretty complex for a system that was meant to be declarative.
- Like HTML and CSS it’s backwards compatible, which means WebAssembly you author today will be guaranteed to still work in a decade or more.
- It’s memory-safe and sandboxed. It can’t read memory outside of itself, plus only what has been explicitly passed into it. It can be timeboxed to run only for a certain duration.
- It’s fast.

## Why develop Orb in Elixir?

Here are the reasons I chose to write Orb in Elixir.

- Established language:
    - Has package manager.
    - Has composable modules with `alias` & `use`.
    - Has syntax highlighting in IDEs, GitHub, and in highlighting libraries.
    - Has language server with autocomplete.
    - Has documentation system.
    - Has unit test library.
    - Has CI integration.
    - Has linting.
    - Integrates with native libraries in Rust and Zig.
    - Has upcoming type system.
- Established frameworks:
    - Can integrate with Phoenix LiveView.
    - Can connect to cloud, databases.
    - Can integrate with Rust.
- Community that is friendly.
- Can be extended with additional functions and macros:
  - Unlike say C’s basic string-inserting preprocessor, Elixir is a full programming language without constraints.
  - We can read files or the network and then generate code.
  - You can create your own DSL. Want to enforce immutable-style programming? Want to add pattern matching? Design a DSL for it.

----

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/orb>.
